import { lstat, readlink, stat } from "node:fs/promises";
import { dirname, isAbsolute, parse, resolve, sep } from "node:path";

import type {
  InstallationCommand,
  InstallationContext,
  SoftwareState,
} from "../software";
import type { Installation } from "../platform";
import { createChildEnvironment } from "../platform/environment";

/** Inspects declared software and links. Never invokes build or install actions. */
/* oxlint-disable no-await-in-loop */
export class DeploymentInspector {
  constructor(
    private readonly installation: Installation,
    private readonly options: {
      readonly cwd: string;
      readonly variables: Readonly<Record<string, string | undefined>>;
    },
  ) {}

  async inspect() {
    const { installation, options } = this;
    const context: InstallationContext = {
      cwd: options.cwd,
      environment: createChildEnvironment(
        installation.environment,
        options.variables,
      ),
    };
    const targets = new Set<string>();
    const names = new Set<string>();
    for (const software of installation.software) {
      if (names.has(software.name))
        throw new Error(`Duplicate software: ${software.name}`);
      names.add(software.name);
      for (const link of software.links) {
        if (!isAbsolute(link.source) || !isAbsolute(link.target)) {
          throw new Error(`Link paths must be absolute: ${software.name}`);
        }
        const target = resolve(link.target);
        if (targets.has(target))
          throw new Error(`Duplicate link target: ${target}`);
        for (const previous of targets) {
          if (
            target.startsWith(previous + sep) ||
            previous.startsWith(target + sep)
          ) {
            throw new Error(`Overlapping link targets: ${previous}, ${target}`);
          }
        }
        targets.add(target);
      }
    }

    const software = [];
    for (const entry of installation.software) {
      let state: SoftwareState | undefined;
      let command: InstallationCommand | undefined;
      if (entry.install) {
        try {
          // Keep provider probes serial and predictable.
          // oxlint-disable-next-line no-await-in-loop
          command = entry.install.command(context);
          // oxlint-disable-next-line no-await-in-loop
          state = await entry.install.inspect(context);
        } catch (error) {
          state = { status: "blocked", reason: String(error) };
        }
      }
      const links = [];
      for (const link of entry.links) {
        try {
          const source = await inspectDirectoryPath(link.source);
          const target = await inspectPath(link.target);
          const parent = await inspectParent(link.target);
          let status = "pending";
          let reason: string | undefined;
          if (state?.status === "blocked") {
            status = "blocked";
            reason = `Software inspection failed: ${state.reason}`;
          } else if (parent) {
            status = "blocked";
            reason = parent;
          } else if (target && !target.isSymbolicLink()) {
            status = "blocked";
            reason = "Target is occupied by a non-symlink.";
          } else if (!source) {
            status = entry.build ? "pending-build" : "blocked";
            reason = entry.build
              ? "Source must be produced and checked after build."
              : "Source does not exist.";
          } else if (state?.status === "missing") {
            status = "pending-install";
            reason = "Source is ready, but the declared software is missing.";
          } else if (target) {
            const current = resolve(
              dirname(link.target),
              // oxlint-disable-next-line no-await-in-loop
              await readlink(link.target),
            );
            status = current === resolve(link.source) ? "satisfied" : "update";
          }
          links.push({ ...link, status, reason });
        } catch (error) {
          links.push({ ...link, status: "blocked", reason: String(error) });
        }
      }
      software.push({
        name: entry.name,
        installation: state,
        command:
          command && entry.install
            ? {
                executable: command.executable,
                args: command.args,
                cwd: command.cwd,
                requirements: entry.install.requirements,
              }
            : undefined,
        build: entry.build
          ? {
              status: "pending",
              requirements: entry.build.requirements,
            }
          : undefined,
        links,
      });
    }
    // Do not serialize the inherited child environment: it may contain secrets.
    return {
      target: installation.target,
      environment: installation.environment,
      software,
    };
  }
}

/* oxlint-enable no-await-in-loop */

async function inspectDirectoryPath(path: string) {
  try {
    return await stat(path);
  } catch (error) {
    if (hasCode(error, "ENOENT")) return undefined;
    throw error;
  }
}

async function inspectPath(path: string) {
  try {
    return await lstat(path);
  } catch (error) {
    if (hasCode(error, "ENOENT")) return undefined;
    throw error;
  }
}

/** Returns a reason when an existing ancestor prevents mkdir/link creation. */
async function inspectParent(path: string): Promise<string | undefined> {
  let current = dirname(path);
  const root = parse(current).root;
  while (current !== root) {
    // oxlint-disable-next-line no-await-in-loop
    const entry = await inspectDirectoryPath(current);
    // oxlint-disable-next-line no-await-in-loop
    if (!entry && (await inspectPath(current))) {
      return `Link parent is a dangling symlink: ${current}`;
    }
    if (entry && !entry.isDirectory()) {
      return `Link parent is occupied by a non-directory: ${current}`;
    }
    current = dirname(current);
  }
  return undefined;
}

function hasCode(error: unknown, code: string): error is NodeJS.ErrnoException {
  return error instanceof Error && "code" in error && error.code === code;
}
