import { parse } from "plist";
import { describe, expect, it } from "vitest";

import {
  createXdgLaunchAgent,
  createXdgEnvironmentScript,
  serializeLaunchAgent,
} from "../src/macos/launch-agent";
import type { XdgEnvironment } from "../src/xdg";

const environment: XdgEnvironment = {
  XDG_CONFIG_HOME: "/Users/example/My Config",
  XDG_DATA_HOME: "/Users/example/O'Brien/data",
  XDG_CACHE_HOME: "/Users/example/.cache",
  XDG_STATE_HOME: "/Users/example/.local/state",
};

describe("XDG LaunchAgent", () => {
  it("runs one generated helper from one Aqua LaunchAgent", () => {
    const helper = "/workspace/profiles/dist/set-xdg-environment.sh";

    expect(parse(serializeLaunchAgent(createXdgLaunchAgent(helper)))).toEqual({
      Label: "dev.qihao.xdg",
      ProgramArguments: ["/bin/sh", helper],
      RunAtLoad: true,
      LimitLoadToSessionType: "Aqua",
    });
  });

  it("generates one correctly quoted launchctl invocation per XDG variable", () => {
    expect(createXdgEnvironmentScript(environment)).toBe(`#!/bin/sh
set -eu

/bin/launchctl setenv XDG_CONFIG_HOME '/Users/example/My Config'
/bin/launchctl setenv XDG_DATA_HOME '/Users/example/O'"'"'Brien/data'
/bin/launchctl setenv XDG_CACHE_HOME '/Users/example/.cache'
/bin/launchctl setenv XDG_STATE_HOME '/Users/example/.local/state'
`);
  });
});
