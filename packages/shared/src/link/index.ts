import {
  lstat,
  mkdir,
  mkdtemp,
  readlink,
  rename,
  rm,
  symlink,
} from "node:fs/promises";
import { dirname, isAbsolute, resolve } from "node:path";

import { ExpectedError } from "../error";

export interface Link {
  readonly source: string;
  readonly target: string;
  /** Optional Node link type for platform-native directory links. */
  readonly type?: "file" | "dir" | "junction";
}

export type SymbolicLinkAction = "keep" | "link" | "update";

export interface SymbolicLinkEvent extends Link {
  readonly phase: "preview" | "completed";
  readonly action: SymbolicLinkAction;
}

export interface SymbolicLinkOptions {
  readonly onlyPreview?: boolean;
  readonly observe?: (event: SymbolicLinkEvent) => void;
}

interface InspectedLink extends Link {
  readonly previousSource?: string;
}

/** Safely creates or updates symbolic links after validating the complete declaration. */
export async function symbolicLink(
  links: readonly Link[],
  { onlyPreview = false, observe }: SymbolicLinkOptions = {},
): Promise<void> {
  assertLinks(links);
  const inspected = await Promise.all(links.map(inspect));

  for (const link of inspected) {
    observe?.({
      phase: "preview",
      action: actionFor(link),
      source: link.source,
      target: link.target,
    });
  }

  if (onlyPreview) return;

  for (const link of inspected) {
    if (link.previousSource === link.source) {
      observe?.({
        phase: "completed",
        action: "keep",
        source: link.source,
        target: link.target,
      });
      continue;
    }

    // Synchronization remains serial so observable changes follow declaration order.
    // oxlint-disable-next-line no-await-in-loop
    await mkdir(dirname(link.target), { recursive: true });
    // oxlint-disable-next-line no-await-in-loop
    await writeLink(link);
    observe?.({
      phase: "completed",
      action: actionFor(link),
      source: link.source,
      target: link.target,
    });
  }
}

function actionFor(link: InspectedLink): SymbolicLinkAction {
  if (link.previousSource === link.source) return "keep";
  return link.previousSource ? "update" : "link";
}

function assertLinks(links: readonly Link[]): void {
  const targets = new Set<string>();

  for (const link of links) {
    if (!isAbsolute(link.source)) {
      throw new ExpectedError(
        `Symbolic link source must be absolute: ${link.source}`,
      );
    }
    if (!isAbsolute(link.target)) {
      throw new ExpectedError(
        `Symbolic link target must be absolute: ${link.target}`,
      );
    }
    if (targets.has(link.target)) {
      throw new ExpectedError(`Duplicate symbolic link target: ${link.target}`);
    }
    targets.add(link.target);
  }
}

async function inspect(link: Link): Promise<InspectedLink> {
  try {
    await lstat(link.source);
  } catch (error) {
    if (hasCode(error, "ENOENT")) {
      throw new ExpectedError(
        `Symbolic link source does not exist: ${link.source}`,
        {
          cause: error,
        },
      );
    }
    throw error;
  }

  try {
    const target = await lstat(link.target);
    if (!target.isSymbolicLink()) {
      throw new ExpectedError(
        `Symbolic link target is occupied: ${link.target}`,
      );
    }

    return {
      ...link,
      previousSource: resolve(
        dirname(link.target),
        await readlink(link.target),
      ),
    };
  } catch (error) {
    if (hasCode(error, "ENOENT")) return link;
    throw error;
  }
}

async function writeLink(link: InspectedLink): Promise<void> {
  if (!link.previousSource) {
    await symlink(link.source, link.target, link.type);
    return;
  }

  await assertUnchanged(link);
  const backupDirectory = await mkdtemp(`${link.target}.dotkit-backup-`);
  const backup = resolve(backupDirectory, "link");
  await rename(link.target, backup);

  try {
    await symlink(link.source, link.target, link.type);
    await rm(backupDirectory, { recursive: true });
  } catch (error) {
    await rename(backup, link.target);
    await rm(backupDirectory, { recursive: true });
    throw error;
  }
}

async function assertUnchanged(link: InspectedLink): Promise<void> {
  let target;
  try {
    target = await lstat(link.target);
  } catch (error) {
    if (hasCode(error, "ENOENT")) {
      throw new ExpectedError(
        `Symbolic link target changed after inspection: ${link.target}`,
        {
          cause: error,
        },
      );
    }
    throw error;
  }

  if (!target.isSymbolicLink()) {
    throw new ExpectedError(
      `Symbolic link target changed after inspection: ${link.target}`,
    );
  }

  const actual = resolve(dirname(link.target), await readlink(link.target));
  if (actual !== link.previousSource) {
    throw new ExpectedError(
      `Symbolic link target changed after inspection: ${link.target}`,
    );
  }
}

function hasCode(error: unknown, code: string): error is NodeJS.ErrnoException {
  return error instanceof Error && "code" in error && error.code === code;
}
