import { execFile } from "node:child_process";
import { promisify } from "node:util";
import type { SoftwareInstall } from ".";

const exec = promisify(execFile);

export function install(
  id: string,
  args: readonly string[] = [],
): SoftwareInstall {
  return {
    requirements: { network: true, elevatedPrivileges: true },
    command: (context) => ({
      executable: "winget.exe",
      args: [
        "install",
        "--id",
        id,
        "--exact",
        "--source",
        "winget",
        "--interactive",
        "--accept-source-agreements",
        ...args,
      ],
      cwd: context.cwd,
      environment: context.environment,
    }),
    async inspect(context) {
      try {
        await exec(
          "winget.exe",
          [
            "list",
            "--id",
            id,
            "--exact",
            "--source",
            "winget",
            "--disable-interactivity",
          ],
          { cwd: context.cwd, env: context.environment },
        );
        return { status: "installed" };
      } catch (error) {
        const text = String(error);
        return isMissingPackage(error)
          ? { status: "missing" }
          : { status: "blocked", reason: text };
      }
    },
  };
}

export function isMissingPackage(error: unknown): boolean {
  return (
    error instanceof Error &&
    "code" in error &&
    typeof error.code === "number" &&
    error.code >>> 0 === 0x8a150014
  );
}

export const winget = { install };
