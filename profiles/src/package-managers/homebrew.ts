import { execFile } from "node:child_process";
import { isAbsolute } from "node:path";
import { promisify } from "node:util";

import type {
  InstallationContext,
  SoftwareInstall,
} from "../deployment/software";

const exec = promisify(execFile);

export interface BrewInstallOptions {
  readonly kind?: "formula" | "cask";
  /** Override PATH lookup and HOMEBREW_BREW_FILE for this action. */
  readonly executable?: string;
}

/** Declares a Homebrew action. No processes or filesystem operations at declaration time. */
function install(
  name: string,
  options: BrewInstallOptions = {},
): SoftwareInstall {
  if (!name || name.startsWith("-") || /[\s\0]/u.test(name)) {
    throw new TypeError(
      "Homebrew package must be a non-empty package name, not an option.",
    );
  }
  const kind = options.kind ?? "formula";
  const executable = options.executable;

  function command(context: InstallationContext) {
    const brew = executable || context.environment.HOMEBREW_BREW_FILE || "brew";
    if (brew !== "brew" && (!isAbsolute(brew) || brew.includes("\0"))) {
      throw new TypeError("Homebrew executable must be an absolute path.");
    }
    return {
      executable: brew,
      args: ["install", `--${kind}`, name],
      cwd: context.cwd,
      environment: {
        ...context.environment,
        HOMEBREW_NO_AUTO_UPDATE: "1",
        HOMEBREW_NO_ANALYTICS: "1",
      },
    };
  }

  return {
    command,
    // Casks may invoke privileged installers; authorization is conservative.
    requirements: { network: true, elevatedPrivileges: kind === "cask" },
    async inspect(context) {
      try {
        const invocation = command(context);
        const { stdout } = await exec(
          invocation.executable,
          ["list", `--${kind}`, "--versions"],
          { cwd: invocation.cwd, env: invocation.environment, timeout: 30_000 },
        );
        const installed = stdout
          .split("\n")
          .some((line) => line.split(/\s+/)[0] === name);
        return { status: installed ? "installed" : "missing" };
      } catch (error) {
        return {
          status: "blocked",
          reason: `Cannot inspect Homebrew package ${name}: ${error instanceof Error ? error.message : String(error)}`,
        };
      }
    },
  };
}

export const brew = { install };
