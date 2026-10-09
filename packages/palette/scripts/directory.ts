import { rename, rm } from "node:fs/promises";
import { basename, dirname, isAbsolute, join } from "node:path";

import { ExpectedError } from "@dotkit/shared/error";

import { hasErrorCode } from "../src/filesystem";

/** Restores or discards the backup left by an interrupted directory replacement. */
export async function recoverDirectoryReplacement(
  destination: string,
): Promise<void> {
  assertAbsolute(destination);
  const backup = backupPath(destination);

  try {
    await rename(backup, destination);
  } catch (error) {
    if (hasErrorCode(error, "ENOENT")) return;
    if (hasErrorCode(error, "EEXIST") || hasErrorCode(error, "ENOTEMPTY")) {
      await rm(backup, { force: true, recursive: true });
      return;
    }
    throw error;
  }
}

/** Atomically publishes a prepared directory and restores the old one on failure. */
export async function replaceDirectory(
  staging: string,
  destination: string,
): Promise<void> {
  assertAbsolute(staging);
  assertAbsolute(destination);
  const backup = backupPath(destination);

  await recoverDirectoryReplacement(destination);
  await rm(backup, { force: true, recursive: true });

  try {
    await rename(destination, backup);
  } catch (error) {
    if (!hasErrorCode(error, "ENOENT")) throw error;
  }

  try {
    await rename(staging, destination);
    await rm(backup, { force: true, recursive: true });
  } catch (error) {
    await recoverDirectoryReplacement(destination);
    throw error;
  }
}

function backupPath(destination: string): string {
  return join(dirname(destination), `.${basename(destination)}-backup`);
}

function assertAbsolute(path: string): void {
  if (!isAbsolute(path)) {
    throw new ExpectedError(`Directory path must be absolute: ${path}`);
  }
}
