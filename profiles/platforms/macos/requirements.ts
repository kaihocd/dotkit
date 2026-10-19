import { execFile } from "node:child_process";
import { promisify } from "node:util";
import type { SoftwareInstall } from "../../src/software";
import { brew } from "../../src/software/homebrew";

const exec = promisify(execFile);

/** Prefer macOS-provided utilities; Homebrew is only a fallback. */
export function systemUtility(name: "curl" | "unzip"): SoftwareInstall {
  const fallback = brew.install(name);
  return {
    ...fallback,
    async inspect(context) {
      try {
        await exec(`/usr/bin/${name}`, [name === "curl" ? "--version" : "-v"], {
          cwd: context.cwd,
          env: context.environment,
          timeout: 30_000,
        });
        return { status: "installed" };
      } catch {
        return fallback.inspect(context);
      }
    },
  };
}

/** Reuse the user's Node/npm installation rather than replacing NVM. */
export const npm: SoftwareInstall = {
  ...brew.install("node"),
  async inspect(context) {
    try {
      await exec("npm", ["--version"], {
        cwd: context.cwd,
        env: context.environment,
        timeout: 30_000,
      });
      return { status: "installed" };
    } catch {
      const node = await brew.install("node").inspect(context);
      if (node.status === "installed")
        return {
          status: "blocked",
          reason:
            "Homebrew Node is installed but npm is unavailable in the deployment PATH.",
        };
      return node;
    }
  },
};

export const cCompiler: SoftwareInstall = {
  requirements: { network: true, elevatedPrivileges: false },
  command: (context) => ({
    executable: "/usr/bin/xcode-select",
    args: ["--install"],
    ...context,
  }),
  async inspect(context) {
    try {
      await exec("/usr/bin/xcrun", ["--find", "clang"], {
        cwd: context.cwd,
        env: context.environment,
        timeout: 30_000,
      });
      return { status: "installed" };
    } catch {
      return { status: "missing" };
    }
  },
};
