import { execFile } from "node:child_process";
import {
  lstat,
  mkdir,
  readFile,
  rename,
  unlink,
  writeFile,
} from "node:fs/promises";
import { join } from "node:path";
import { promisify } from "node:util";
import type { PlatformContext } from "../../src/platform";

const exec = promisify(execFile);
const marker = "# Managed by Dotkit: Arch user XDG environment\n";

/** Publish user-service environment only; existing desktop processes need a new login. */
export async function publishEnvironment(
  context: PlatformContext,
): Promise<void> {
  const { home, xdg } = context.environment;
  // Keep the generator's bootstrap location unambiguous on initial login.
  if (xdg.XDG_CONFIG_HOME !== join(home, ".config"))
    throw new Error(
      "Arch environment publication currently requires XDG_CONFIG_HOME=$HOME/.config.",
    );
  const directory = join(home, ".config/environment.d");
  const target = join(directory, "60-dotkit.conf");
  const entries = Object.entries(xdg);
  for (const [name, value] of entries) {
    if (!/^\/[A-Za-z0-9_./ @:+-]*$/.test(value))
      throw new Error(
        `Cannot safely serialize ${name} into environment.d: ${value}`,
      );
  }
  const content =
    marker +
    entries.map(([name, value]) => `${name}="${value}"`).join("\n") +
    "\n";
  // Never follow existing symlinks or replace an unrelated environment file.
  for (const path of [join(home, ".config"), directory, target]) {
    // oxlint-disable-next-line no-await-in-loop
    const info = await lstat(path).catch((error: NodeJS.ErrnoException) => {
      if (error.code === "ENOENT") return undefined;
      throw error;
    });
    if (!info) continue;
    if (
      info.isSymbolicLink() ||
      (path === target ? !info.isFile() : !info.isDirectory())
    )
      throw new Error(`Unsafe environment configuration path: ${path}`);
  }
  const existing = await readFile(target, "utf8").catch(
    (error: NodeJS.ErrnoException) => {
      if (error.code === "ENOENT") return undefined;
      throw error;
    },
  );
  if (existing !== undefined && !existing.startsWith(marker))
    throw new Error(
      `Refusing to replace unmanaged environment file: ${target}`,
    );

  const options = {
    cwd: context.cwd,
    env: { ...context.variables, HOME: home },
    timeout: 30_000,
  };
  const before = await exec(
    "/usr/bin/systemctl",
    ["--user", "show-environment"],
    options,
  );
  const managerConfig = before.stdout
    .split("\n")
    .find((line) => line.startsWith("XDG_CONFIG_HOME="))
    ?.slice("XDG_CONFIG_HOME=".length);
  if (managerConfig && managerConfig !== xdg.XDG_CONFIG_HOME)
    throw new Error(
      `User manager uses a different XDG_CONFIG_HOME: ${managerConfig}`,
    );
  if (context.onlyPreview) return;

  await mkdir(directory, { recursive: true });
  if (existing !== content) {
    const temporary = `${target}.${process.pid}.tmp`;
    await writeFile(temporary, content, { flag: "wx", mode: 0o600 });
    try {
      await rename(temporary, target);
    } finally {
      await unlink(temporary).catch((error: NodeJS.ErrnoException) => {
        if (error.code !== "ENOENT") throw error;
      });
    }
  }
  await exec("/usr/bin/systemctl", ["--user", "daemon-reload"], options);
  const after = await exec(
    "/usr/bin/systemctl",
    ["--user", "show-environment"],
    options,
  );
  const actual = new Set(after.stdout.split("\n"));
  const missing = entries.filter(
    ([name, value]) => !actual.has(`${name}=${value}`),
  );
  if (missing.length)
    throw new Error(
      `Environment file saved, but user-manager verification failed: ${missing.map(([name]) => name).join(", ")}. Check other environment.d overrides. Existing sessions were not changed.`,
    );
  console.log(`\nUser environment verified: ${target}`);
  console.log(
    "Log out of the Arch desktop and log in again before testing GUI applications; reconnecting SSH is not sufficient.",
  );
}
