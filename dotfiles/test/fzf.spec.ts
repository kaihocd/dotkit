import { execFile } from "node:child_process";
import { resolve } from "node:path";
import { promisify } from "node:util";

import { expect, it } from "vitest";

const executeFile = promisify(execFile);
const fzfConfig = resolve(import.meta.dirname, "../configs/zsh/fzf.zsh");

it("binds files to Ctrl-F, history to Ctrl-R, and directories to Ctrl-G", async () => {
  const script = `
    source ${JSON.stringify(fzfConfig)}
    bindkey -M viins '^F'
    bindkey -M viins '^R'
    bindkey -M viins '^G'
    bindkey -M viins '^T'
  `;

  const { stdout } = await executeFile("/bin/zsh", ["-c", script]);
  const bindings = stdout.trim().split("\n");

  expect(bindings[0]).toContain("fzf-file-widget");
  expect(bindings[1]).toContain("fzf-history-widget");
  expect(bindings[2]).toContain("zoxide-cd-widget");
  expect(bindings[3]).not.toContain("fzf-file-widget");
});

it("adapts semantic search settings to the integrations' official variables", async () => {
  const script = `
    source ${JSON.stringify(fzfConfig)}
    print -r -- "$_FZF_FILE_COMMAND"
    print -r -- "$_FZF_FILE_OPTS"
    print -r -- "$_FZF_HISTORY_OPTS"
    print -r -- "$_FZF_DIRECTORY_OPTS"
    [[ $FZF_CTRL_T_COMMAND == $_FZF_FILE_COMMAND ]]
    [[ $FZF_CTRL_T_OPTS == $_FZF_FILE_OPTS ]]
    [[ $FZF_CTRL_R_OPTS == $_FZF_HISTORY_OPTS ]]
    [[ $_ZO_FZF_OPTS == "$FZF_DEFAULT_OPTS $_FZF_DIRECTORY_OPTS" ]]
  `;

  const { stdout } = await executeFile("/bin/zsh", ["-c", script]);

  expect(stdout).toContain("fd --type f");
  expect(stdout).toContain("Files");
  expect(stdout).toContain("History");
  expect(stdout).toContain("Directories");
});

it("opens file search without the current command line as its query", async () => {
  const script = `
    fzf() {
      if [[ $1 == --zsh ]]; then
        print -r -- '__fzf_select() { print -r -- "$FZF_CTRL_T_OPTS" >&2; return 1; }'
      fi
    }
    zle() { return 0 }
    source ${JSON.stringify(fzfConfig)}

    LBUFFER='current-command-line'
    fzf-file-widget || true
  `;

  const { stderr } = await executeFile("/bin/zsh", ["-c", script]);

  expect(stderr).toContain("Files");
  expect(stderr).not.toContain("current-command-line");
});

it("opens zoxide directory search without the current command line as its query", async () => {
  const script = `
    fzf() {
      if [[ $1 == --zsh ]]; then
        print -r -- '__fzf_select() { return 1; }'
      fi
    }
    zle() { return 0 }
    source ${JSON.stringify(fzfConfig)}
    zoxide() {
      print -r -- "$_ZO_FZF_OPTS" >&2
      print -r -- /tmp
    }

    LBUFFER='current-command-line'
    zoxide-cd-widget
  `;

  const { stderr } = await executeFile("/bin/zsh", ["-c", script]);

  expect(stderr).toContain("Directories");
  expect(stderr).toContain("--height=60%");
  expect(stderr).toContain("--layout=reverse");
  expect(stderr).toContain("--style=minimal");
  expect(stderr).not.toContain("current-command-line");
});
