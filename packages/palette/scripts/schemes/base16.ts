import { readdir, readFile } from "node:fs/promises";
import {
  basename,
  extname,
  isAbsolute,
  join,
  normalize,
  posix,
} from "node:path";

import { ExpectedError } from "@dotkit/shared/error";

import { hasErrorCode } from "../../src/filesystem";
import { parse } from "yaml";
import { z } from "zod";

const paletteKeys = [
  "base00",
  "base01",
  "base02",
  "base03",
  "base04",
  "base05",
  "base06",
  "base07",
  "base08",
  "base09",
  "base0A",
  "base0B",
  "base0C",
  "base0D",
  "base0E",
  "base0F",
] as const;

const colorSchema = z.string().regex(/^#[0-9a-fA-F]{6}$/);
const paletteSchema = z
  .object(
    Object.fromEntries(paletteKeys.map((key) => [key, colorSchema])) as {
      [Key in (typeof paletteKeys)[number]]: typeof colorSchema;
    },
  )
  .strict();
const schemeSchema = z
  .object({
    system: z.literal("base16"),
    name: z.string().min(1),
    author: z.string().optional(),
    variant: z.enum(["dark", "light"]),
    slug: z.string().optional(),
    description: z.string().optional(),
    palette: paletteSchema,
  })
  .strict();

export type Base16Scheme = z.infer<typeof schemeSchema>;

/** A validated scheme paired with its catalog ID and diagnostic source path. */
export interface SourceScheme {
  readonly id: string;
  readonly source: string;
  readonly scheme: Base16Scheme;
}

/**
 * Reads and validates every Base16 YAML file in an absolute directory.
 *
 * Files are returned in ID order so catalog builds and validation failures are
 * deterministic across filesystems.
 */
export async function readBase16Schemes(
  directory: string,
): Promise<readonly SourceScheme[]> {
  if (!isAbsolute(directory)) {
    throw new ExpectedError(
      `Base16 schemes directory must be absolute: ${directory}`,
    );
  }

  const normalizedDirectory = normalize(directory);
  let fileNames: string[];

  try {
    // readdir order is filesystem-dependent; the catalog must not be.
    fileNames = (await readdir(normalizedDirectory))
      .filter((fileName) => /\.ya?ml$/i.test(fileName))
      .toSorted();
  } catch (error) {
    if (hasErrorCode(error, "ENOENT")) {
      throw new ExpectedError(
        `Missing Base16 schemes directory: ${normalizedDirectory}`,
        {
          cause: error,
        },
      );
    }

    throw error;
  }

  if (fileNames.length === 0) {
    throw new ExpectedError(
      `No Base16 YAML schemes found in ${normalizedDirectory}`,
    );
  }

  const schemes: SourceScheme[] = [];
  const seenIds = new Set<string>();

  for (const fileName of fileNames) {
    const id = basename(fileName, extname(fileName));
    const source = posix.join("base16", fileName);

    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(id)) {
      throw new ExpectedError(`Invalid Base16 theme ID: ${id}`);
    }

    if (seenIds.has(id)) {
      throw new ExpectedError(`Duplicate Base16 theme ID: ${id}`);
    }

    let value: unknown;

    try {
      // Read in order so the first invalid filename or file is deterministic.
      // oxlint-disable-next-line no-await-in-loop
      const content = await readFile(
        join(normalizedDirectory, fileName),
        "utf8",
      );
      value = parse(content);
    } catch (error) {
      throw new ExpectedError(`Invalid YAML in ${source}`, { cause: error });
    }

    const result = schemeSchema.safeParse(value);
    if (!result.success) {
      throw new ExpectedError(`Invalid Base16 scheme ${source}`, {
        cause: result.error,
      });
    }

    seenIds.add(id);
    schemes.push({ id, source, scheme: result.data });
  }

  return schemes;
}
