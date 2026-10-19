import { execFile } from "node:child_process";
import {
  lstat,
  mkdir,
  mkdtemp,
  readFile,
  readlink,
  rename,
  rm,
  stat,
  writeFile,
} from "node:fs/promises";
import { dirname, isAbsolute, join } from "node:path";
import { promisify } from "node:util";

import type { PlatformContext } from "../../src/deployment/platform";

import { build } from "plist";

import {
  XDG_NAMES,
  type XdgEnvironment,
} from "../../src/deployment/environment";

export const XDG_LAUNCH_AGENT_LABEL = "dev.qihao.xdg";

export interface LaunchAgent {
  readonly label: string;
  readonly program: string;
  readonly arguments?: readonly string[];
  readonly runAtLoad?: boolean;
  readonly sessionType?:
    "Aqua" | "Background" | "LoginWindow" | "StandardIO" | "System";
}

/** Defines the single login agent that publishes the XDG environment. */
export function createXdgLaunchAgent(helper: string): LaunchAgent {
  if (!isAbsolute(helper)) {
    throw new TypeError(`XDG environment helper must be absolute: ${helper}`);
  }

  return {
    label: XDG_LAUNCH_AGENT_LABEL,
    program: "/bin/sh",
    arguments: [helper],
    runAtLoad: true,
    sessionType: "Aqua",
  };
}

/** Generates the helper invoked by the XDG LaunchAgent. */
export function createXdgEnvironmentScript(
  environment: XdgEnvironment,
): string {
  const commands = XDG_NAMES.map(
    (name) => `/bin/launchctl setenv ${name} ${quoteShell(environment[name])}`,
  );

  return `#!/bin/sh\nset -eu\n\n${commands.join("\n")}\n`;
}

const exec = promisify(execFile);
const ownership = "Managed by dotkit: macOS XDG environment";

/** macOS-local command boundary, replaceable in isolated tests. */
export type Launchctl = (args: readonly string[]) => Promise<string>;
const launchctl: Launchctl = async (args) => {
  const result = await exec("/bin/launchctl", [...args], { timeout: 30_000 });
  return result.stdout;
};

export async function prepareXdgEnvironment(
  context: PlatformContext,
): Promise<void> {
  await deployXdgEnvironment(context, launchctl, process.getuid?.());
}

/** All persistent files and session changes remain owned by this platform. */
export async function deployXdgEnvironment(
  context: PlatformContext,
  run: Launchctl,
  uid: number | undefined,
): Promise<void> {
  const helper = join(
    context.environment.xdg.XDG_CONFIG_HOME,
    "environment/xdg.sh",
  );
  const plist = join(
    context.environment.home,
    "Library/LaunchAgents/dev.qihao.xdg.plist",
  );

  const script = createXdgEnvironmentScript(context.environment.xdg).replace(
    "#!/bin/sh\n",
    `#!/bin/sh\n# ${ownership}\n`,
  );
  const document = serializeLaunchAgent(createXdgLaunchAgent(helper)).replace(
    "<plist",
    `<!-- ${ownership} -->\n<plist`,
  );
  const files = [
    { path: helper, content: script },
    { path: plist, content: document },
  ];
  // Validate all targets before the first write; preview never invokes launchctl.
  const previous = await Promise.all(
    files.map((file) => inspectManagedFile(file.path)),
  );
  if (context.onlyPreview) return;
  if (uid === undefined || !Number.isInteger(uid) || uid < 0) {
    throw new Error("macOS environment deployment requires a user ID.");
  }
  const domain = `gui/${uid}`;
  // Refuse execution outside a live GUI session before changing files.
  await run(["print", domain]);
  for (const [index, file] of files.entries()) {
    // oxlint-disable-next-line no-await-in-loop
    await writeManagedFile(file.path, file.content, previous[index]);
  }
  const service = `${domain}/${XDG_LAUNCH_AGENT_LABEL}`;
  let loaded = false;
  try {
    await run(["print", service]);
    loaded = true;
  } catch {
    // bootstrap below must succeed; a failed probe is not treated as success.
  }
  if (loaded) await run(["bootout", service]);
  await run(["bootstrap", domain, plist]);
  await run(["print", service]);
  // Publish synchronously: RunAtLoad is asynchronous and cannot be our barrier.
  for (const name of XDG_NAMES) {
    // oxlint-disable-next-line no-await-in-loop
    await run(["setenv", name, context.environment.xdg[name]]);
  }
  await checkPublishedEnvironment(context, run);
}

export async function verifyXdgEnvironment(
  context: PlatformContext,
): Promise<void> {
  if (!context.onlyPreview) await checkPublishedEnvironment(context, launchctl);
}

async function checkPublishedEnvironment(
  context: PlatformContext,
  run: Launchctl,
): Promise<void> {
  for (const name of XDG_NAMES) {
    // oxlint-disable-next-line no-await-in-loop
    const value = await run(["getenv", name]);
    if (value.replace(/\n$/, "") !== context.environment.xdg[name]) {
      throw new Error(`launchctl environment verification failed: ${name}`);
    }
  }
}

/* oxlint-disable no-await-in-loop */
async function inspectManagedFile(path: string): Promise<string | undefined> {
  let parent = dirname(path);
  while (true) {
    try {
      const entry = await lstat(parent);
      if (!entry.isDirectory() && !(await stat(parent)).isDirectory()) {
        throw new Error(`Not a directory: ${parent}`);
      }
    } catch (error) {
      if (!isMissing(error)) throw error;
      // A dangling directory symlink must not be treated as an absent directory.
      const entry = await lstat(parent).catch((cause: unknown) => {
        if (!isMissing(cause)) throw cause;
        return undefined;
      });
      if (entry)
        throw new Error(`Broken parent path: ${parent}`, { cause: error });
    }
    const next = dirname(parent);
    if (next === parent) break;
    parent = next;
  }
  let entry;
  try {
    entry = await lstat(path);
  } catch (error) {
    if (isMissing(error)) return undefined;
    throw error;
  }
  if (entry.isSymbolicLink()) {
    const destination = await readlink(path);
    throw new Error(
      `Existing symlink requires an explicit migration decision: ${path} -> ${destination}. No files were changed.`,
    );
  }
  if (!entry.isFile()) throw new Error(`Refusing non-file target: ${path}`);
  const content = await readFile(path, "utf8");
  if (!content.includes(ownership))
    throw new Error(`Refusing unmanaged file: ${path}`);
  return content;
}

/* oxlint-enable no-await-in-loop */

async function writeManagedFile(
  path: string,
  content: string,
  previous: string | undefined,
): Promise<void> {
  if ((await inspectManagedFile(path)) !== previous)
    throw new Error(`Target changed: ${path}`);
  if (previous === content) return;
  await mkdir(dirname(path), { recursive: true });
  const temporary = await mkdtemp(join(dirname(path), ".dotkit-xdg-"));
  try {
    const staged = join(temporary, "content");
    await writeFile(staged, content, { mode: 0o644, flag: "wx" });
    if ((await inspectManagedFile(path)) !== previous)
      throw new Error(`Target changed: ${path}`);
    await rename(staged, path);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
}

function isMissing(error: unknown): boolean {
  return error instanceof Error && "code" in error && error.code === "ENOENT";
}

export function serializeLaunchAgent(agent: LaunchAgent): string {
  return build(
    {
      Label: agent.label,
      ProgramArguments: [agent.program, ...(agent.arguments ?? [])],
      RunAtLoad: agent.runAtLoad ?? false,
      ...(agent.sessionType === undefined
        ? {}
        : { LimitLoadToSessionType: agent.sessionType }),
    },
    { pretty: true },
  );
}

function quoteShell(value: string): string {
  return `'${value.replaceAll("'", `'"'"'`)}'`;
}
