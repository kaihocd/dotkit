import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { parseArgs, promisify } from "node:util";

import { ExpectedError } from "@dotkit/shared/error";
import { symbolicLink, type SymbolicLinkEvent } from "@dotkit/shared/link";
import { reportSymbolicLinkToTerminal } from "@dotkit/shared/link/terminal";
import { success, warn } from "@dotkit/shared/output";
import { runScript } from "@dotkit/shared/script";

import { XDG_LAUNCH_AGENT_LABEL } from "../src/macos/launch-agent";

const exec = promisify(execFile);

export interface SlinkOptions {
  /** Inspects and displays the link without changing the filesystem or launchd. */
  readonly onlyPreview?: boolean;
  readonly home?: string;
  readonly uid?: number;
  readonly distributionDirectory?: string;
  readonly launchctl?: string;
  readonly platform?: NodeJS.Platform;
  readonly observe?: (event: SlinkEvent) => void;
}

export type SlinkEvent =
  | SymbolicLinkEvent
  | { readonly type: "loaded"; readonly target: string }
  | { readonly type: "restart-notice" };

/** Links and reloads the built Profiles LaunchAgent. */
export async function slink({
  onlyPreview = false,
  home = homedir(),
  uid = currentUid(),
  distributionDirectory = resolve(import.meta.dirname, "..", "dist"),
  launchctl = "/bin/launchctl",
  platform = process.platform,
  observe,
}: SlinkOptions = {}): Promise<void> {
  if (platform !== "darwin") {
    throw new ExpectedError(
      "Profiles symbolic-link installation is currently supported only on macOS.",
    );
  }

  const source = join(distributionDirectory, `${XDG_LAUNCH_AGENT_LABEL}.plist`);
  const target = join(
    home,
    "Library",
    "LaunchAgents",
    `${XDG_LAUNCH_AGENT_LABEL}.plist`,
  );
  const domain = `gui/${uid}`;
  const service = `${domain}/${XDG_LAUNCH_AGENT_LABEL}`;

  await symbolicLink([{ source, target }], { onlyPreview, observe });
  if (onlyPreview) return;

  await bootout(launchctl, service);
  await exec(launchctl, ["bootstrap", domain, target]);

  observe?.({ type: "loaded", target });
  observe?.({ type: "restart-notice" });
}

/** Parses the intentionally small command-line grammar for the slink script. */
export function parseSlinkArguments(
  arguments_: readonly string[],
): Pick<SlinkOptions, "onlyPreview"> {
  try {
    const { values } = parseArgs({
      args: [...arguments_],
      options: {
        "only-preview": {
          type: "boolean",
          default: false,
        },
      },
      strict: true,
      allowPositionals: false,
    });

    return { onlyPreview: values["only-preview"] };
  } catch (cause) {
    throw new ExpectedError("Usage: pnpm slink [--only-preview]", { cause });
  }
}

function currentUid(): number {
  const uid = process.getuid?.();
  if (uid === undefined) {
    throw new ExpectedError("Unable to determine the current user UID.");
  }
  return uid;
}

async function bootout(launchctl: string, service: string): Promise<void> {
  try {
    await exec(launchctl, ["bootout", service]);
  } catch (error) {
    if (hasExitCode(error, 3)) return;
    throw error;
  }
}

function hasExitCode(error: unknown, code: number): boolean {
  return (
    error !== null &&
    typeof error === "object" &&
    "code" in error &&
    error.code === code
  );
}

function reportSlinkToTerminal(event: SlinkEvent): void {
  if ("phase" in event) {
    reportSymbolicLinkToTerminal(event);
    return;
  }
  if (event.type === "loaded") {
    success(event.target, { label: "LOAD" });
    return;
  }
  warn("Restart already-running applications to inherit the XDG environment.", {
    label: "NOTICE",
  });
}

if (import.meta.main) {
  await runScript(
    () =>
      slink({
        ...parseSlinkArguments(process.argv.slice(2)),
        observe: reportSlinkToTerminal,
      }),
    { label: "PROFILES_ERROR" },
  );
}
