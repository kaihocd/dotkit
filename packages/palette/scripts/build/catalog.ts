import { mkdir, rm, writeFile } from "node:fs/promises";
import { basename, dirname, isAbsolute, join, normalize } from "node:path";

import { ExpectedError } from "@dotkit/shared/error";
import { recoverDirectoryReplacement, replaceDirectory } from "../directory";

import { convertToBase24 } from "./base24";
import type { SourceScheme } from "../schemes/base16";
import { parseCatalogManifest, type CatalogManifest } from "../../src/theme";

export interface CatalogSource {
  readonly revision: string;
  readonly schemes: readonly SourceScheme[];
}

export interface BuildCatalogOptions {
  readonly directory: string;
  readonly defaultTheme: string;
  readonly source: CatalogSource;
}

/**
 * Converts a validated scheme snapshot into a complete catalog directory.
 *
 * Publication is atomic: callers observe either the previous complete catalog
 * or the new complete catalog, never a partially written directory.
 */
export async function buildCatalog({
  directory,
  defaultTheme,
  source,
}: BuildCatalogOptions): Promise<CatalogManifest> {
  if (!isAbsolute(directory)) {
    throw new ExpectedError(`Catalog directory must be absolute: ${directory}`);
  }

  const catalogDirectory = normalize(directory);
  let manifest: CatalogManifest;

  try {
    manifest = parseCatalogManifest({
      revision: source.revision,
      defaultTheme,
      themes: source.schemes.map(({ id }) => id).toSorted(),
    });
  } catch (error) {
    throw new ExpectedError("Cannot build catalog manifest", { cause: error });
  }

  // Complete every conversion before writing any catalog files.
  const themes = source.schemes.map((scheme) => convertToBase24(scheme));
  const parentDirectory = dirname(catalogDirectory);
  const name = basename(catalogDirectory);
  const buildDirectory = join(parentDirectory, `.${name}-build`);

  await mkdir(parentDirectory, { recursive: true });
  // Restore a backup left by a process interrupted during an earlier publish.
  await recoverDirectoryReplacement(catalogDirectory);
  await rm(buildDirectory, { force: true, recursive: true });

  try {
    await mkdir(buildDirectory);
    await Promise.all([
      writeJson(join(buildDirectory, "manifest.json"), manifest),
      ...themes.map((theme) =>
        writeJson(join(buildDirectory, `${theme.id}.json`), theme),
      ),
    ]);
    // Rename the fully prepared staging directory across the publication boundary.
    await replaceDirectory(buildDirectory, catalogDirectory);
    return manifest;
  } finally {
    await rm(buildDirectory, { force: true, recursive: true });
  }
}

async function writeJson(path: string, value: unknown): Promise<void> {
  await writeFile(path, `${JSON.stringify(value, null, 2)}\n`, {
    encoding: "utf8",
    mode: 0o644,
  });
}
