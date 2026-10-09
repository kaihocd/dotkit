import { execFile } from "node:child_process";
import { promisify } from "node:util";

import { describe, expect, it } from "vitest";

const exec = promisify(execFile);
const ZSHENV = new URL("../configs/zsh/zshenv.zsh", import.meta.url);

function cleanEnvironment(): NodeJS.ProcessEnv {
  const environment = { ...process.env };
  delete environment.XDG_CONFIG_HOME;
  delete environment.XDG_DATA_HOME;
  delete environment.XDG_CACHE_HOME;
  delete environment.XDG_STATE_HOME;
  delete environment.ZDOTDIR;
  return environment;
}

describe("zshenv", () => {
  it("reports missing Profiles environment without deriving root paths", async () => {
    const { stderr, stdout } = await exec(
      "/bin/zsh",
      ["-c", `source ${JSON.stringify(ZSHENV.pathname)}; print -r -- $ZDOTDIR`],
      { env: cleanEnvironment() },
    );

    expect(stderr).toContain(
      "DOTFILES_ERROR Profiles XDG environment is unavailable",
    );
    expect(stderr).not.toContain("mkdir:");
    expect(stdout.trim()).toBe("");
  });
});
