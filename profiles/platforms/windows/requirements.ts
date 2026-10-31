import { execFile } from "node:child_process";
import { promisify } from "node:util";
import type { SoftwareInstall } from "../../src/software";

const exec = promisify(execFile);

/** Bootstrap/system utilities are checked, never installed or repaired. */
export function prerequisite(
  executable: string,
  args: string[],
): SoftwareInstall {
  return {
    requirements: { network: false, elevatedPrivileges: false },
    command: (context) => ({ executable, args, ...context }),
    async inspect(context) {
      try {
        await exec(executable, args, {
          cwd: context.cwd,
          env: context.environment,
          timeout: 30_000,
        });
        return { status: "installed" };
      } catch (error) {
        return {
          status: "blocked",
          reason: `Required utility ${executable}: ${String(error)}`,
        };
      }
    },
  };
}
