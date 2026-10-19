import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import { promisify } from "node:util";
import type { PlatformContext } from "../../src/platform";
import type { SoftwareInstallation } from "../../src/software";
import { createChildEnvironment } from "../../src/platform/environment";
import { runInstallationCommand } from "../../src/software";

const exec = promisify(execFile);

/** Validate read-only first; the execution callback installs one native package transaction. */
export async function checkArch(
  context: PlatformContext,
  software: readonly SoftwareInstallation[],
) {
  if (process.platform !== "linux")
    throw new Error("Arch deployment requires Linux.");
  const release = await readFile("/etc/os-release", "utf8");
  const identities = [...release.matchAll(/^(?:ID|ID_LIKE)=(.*)$/gm)].flatMap(
    (match) => match[1]!.replace(/["']/g, "").split(/\s+/),
  );
  if (!identities.includes("arch"))
    throw new Error("Expected Arch Linux or an Arch-derived distribution.");
  if (process.getuid?.() === 0)
    throw new Error("Run Dotkit as your normal user, not with sudo.");
  const environment = createChildEnvironment(
    context.environment,
    context.variables,
  );
  const packages = software.flatMap((entry) => {
    if (!entry.install) return [];
    const command = entry.install.command({ cwd: context.cwd, environment });
    if (command.executable !== "/usr/bin/pacman" || command.args.length !== 3)
      throw new Error(
        `Unsupported Arch installation declaration: ${entry.name}`,
      );
    return [command.args[2]!];
  });
  const { stdout } = await exec("/usr/bin/pacman", ["-Qq"], {
    cwd: context.cwd,
    env: { ...context.variables, HOME: context.environment.home },
    timeout: 30_000,
  });
  const installed = new Set(stdout.split("\n"));
  const missing = packages.filter((name) => !installed.has(name));
  if (!missing.length || context.onlyPreview) return;
  console.log(
    `\nInstall ${missing.length} missing packages: ${missing.join(", ")}`,
  );
  console.log(
    "This includes a full system upgrade. Review pacman's transaction before confirming.",
  );
  await runInstallationCommand({
    executable: "/usr/bin/sudo",
    args: ["--", "/usr/bin/pacman", "-Syu", "--needed", ...missing],
    cwd: context.cwd,
    environment,
  });
  const verified = await exec("/usr/bin/pacman", ["-Qq"], {
    cwd: context.cwd,
    env: environment,
    timeout: 30_000,
  });
  const installedAfter = new Set(verified.stdout.split("\n"));
  const remaining = packages.filter((name) => !installedAfter.has(name));
  if (remaining.length)
    throw new Error(`Package verification failed: ${remaining.join(", ")}`);
}
