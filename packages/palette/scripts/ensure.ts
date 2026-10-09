import { execFile } from "node:child_process";
import {
  cp,
  lstat,
  mkdir,
  mkdtemp,
  rename,
  rm,
  writeFile,
} from "node:fs/promises";
import { dirname, join } from "node:path";
import { promisify } from "node:util";

import { runScript } from "@dotkit/shared/script";
import { SCHEME_DIRECTORY, SCHEME_REVISION } from "../settings";
import { readBase16Schemes } from "./schemes/base16";

const exec = promisify(execFile);

/** Validate existing input; acquire the pinned snapshot only when absent. */
export async function ensureSchemes(
  destination = SCHEME_DIRECTORY,
): Promise<void> {
  try {
    await lstat(destination);
    // Invalid or user-modified input must never be silently replaced.
    await readBase16Schemes(destination);
    return;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
  }

  await mkdir(dirname(destination), { recursive: true });
  const staging = await mkdtemp(join(dirname(destination), ".ensure-"));
  try {
    const response = await fetch(
      `https://codeload.github.com/tinted-theming/schemes/tar.gz/${SCHEME_REVISION}`,
      { signal: AbortSignal.timeout(60_000) },
    );
    if (!response.ok)
      throw new Error(`Scheme download failed: HTTP ${response.status}`);
    const archive = join(staging, "schemes.tar.gz");
    await writeFile(archive, Buffer.from(await response.arrayBuffer()));
    await exec("tar", ["-xzf", archive, "-C", staging]);
    const input = join(staging, `schemes-${SCHEME_REVISION}`, "base16");
    await readBase16Schemes(input);
    const prepared = join(staging, "prepared");
    await cp(input, prepared, { recursive: true });
    // Refuse a concurrent installation rather than replacing its contents.
    try {
      await lstat(destination);
      throw new Error(
        `Scheme destination appeared during download: ${destination}`,
      );
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
    await rename(prepared, destination);
  } finally {
    await rm(staging, { recursive: true, force: true });
  }
}

if (import.meta.main) {
  await runScript(() => ensureSchemes(), { label: "PALETTE_ERROR" });
}
