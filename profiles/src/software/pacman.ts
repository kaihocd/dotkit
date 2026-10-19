import { execFile } from "node:child_process";
import { promisify } from "node:util";
import type { SoftwareInstall } from "./index";

const exec = promisify(execFile);

/** Native package names only. Never refresh databases or inject a privilege wrapper. */
function install(name: string): SoftwareInstall {
  if (!/^[a-z0-9][a-z0-9@._+-]*$/.test(name))
    throw new TypeError(`Invalid pacman package name: ${name}`);
  return {
    requirements: { network: true, elevatedPrivileges: true },
    command: (context) => ({
      executable: "/usr/bin/pacman",
      args: ["-S", "--needed", name],
      cwd: context.cwd,
      environment: context.environment,
    }),
    async inspect(context) {
      try {
        const { stdout } = await exec("/usr/bin/pacman", ["-Qq"], {
          cwd: context.cwd,
          env: context.environment,
          timeout: 30_000,
        });
        return {
          status: stdout.split("\n").includes(name) ? "installed" : "missing",
        };
      } catch (error) {
        return {
          status: "blocked",
          reason: `Cannot inspect pacman: ${String(error)}`,
        };
      }
    },
  };
}

export const pacman = { install };
