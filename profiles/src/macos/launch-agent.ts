import { isAbsolute } from "node:path";

import { build } from "plist";

import { XDG_NAMES, type XdgEnvironment } from "../xdg";

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

/** Serializes a LaunchAgent to the plist document consumed by launchd. */
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
