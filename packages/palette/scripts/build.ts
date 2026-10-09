import { execFile } from "node:child_process";
import { chmod, mkdir, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { promisify } from "node:util";

import { success } from "@dotkit/shared/output";
import { runScript } from "@dotkit/shared/script";
import { build as bundle } from "esbuild";

import {
  BUILD_DIRECTORY,
  DEFAULT_THEME,
  DIST_DIRECTORY,
  PACKAGE_DIRECTORY,
  SCHEME_DIRECTORY,
  SCHEME_REVISION,
} from "../settings";
import { recoverDirectoryReplacement, replaceDirectory } from "./directory";
import { buildCatalog } from "./build/catalog";
import { renderZshCompletion } from "./build/completion";
import { readBase16Schemes } from "./schemes/base16";

const execFileAsync = promisify(execFile);

/** Builds and atomically publishes the Palette executable and runtime catalog. */
export async function build(): Promise<void> {
  await recoverDirectoryReplacement(DIST_DIRECTORY);
  await rm(BUILD_DIRECTORY, { force: true, recursive: true });
  await mkdir(BUILD_DIRECTORY, { recursive: true });

  try {
    const executable = join(BUILD_DIRECTORY, "palette.js");
    await bundle({
      entryPoints: [join(PACKAGE_DIRECTORY, "cli/index.ts")],
      outfile: executable,
      bundle: true,
      format: "esm",
      platform: "node",
      target: "node24",
      packages: "bundle",
      sourcemap: true,
      banner: {
        js: "import { createRequire } from 'node:module'; const require = createRequire(import.meta.url);",
      },
    });
    await chmod(executable, 0o755);

    const source = {
      revision: SCHEME_REVISION,
      schemes: await readBase16Schemes(SCHEME_DIRECTORY),
    };
    const manifest = await buildCatalog({
      directory: join(BUILD_DIRECTORY, "catalog"),
      defaultTheme: DEFAULT_THEME,
      source,
    });
    const completionDirectory = join(BUILD_DIRECTORY, "completions");
    await mkdir(completionDirectory, { recursive: true });
    await writeFile(
      join(completionDirectory, "_palette"),
      renderZshCompletion(manifest),
      "utf8",
    );

    await execFileAsync(process.execPath, [executable, "--help"]);
    await replaceDirectory(BUILD_DIRECTORY, DIST_DIRECTORY);
    success(`Palette with ${manifest.themes.length} themes.`, {
      label: "BUILD",
    });
  } catch (error) {
    await rm(BUILD_DIRECTORY, { force: true, recursive: true });
    throw error;
  }
}

if (import.meta.main) {
  await runScript(build, { label: "PALETTE_ERROR" });
}
