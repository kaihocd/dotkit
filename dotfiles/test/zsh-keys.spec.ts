import { execFile } from "node:child_process";
import { rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { promisify } from "node:util";

import { expect, it } from "vitest";

const executeFile = promisify(execFile);
const keysConfig = resolve(import.meta.dirname, "../configs/zsh/keys.zsh");

it("binds Insert Ctrl-W to Vim-style word deletion without the Insert boundary", async () => {
  const script = `
    zmodload zsh/terminfo
    source ${JSON.stringify(keysConfig)}
    bindkey -M viins '^W'
  `;

  const { stdout } = await executeFile("/bin/zsh", ["-c", script]);

  expect(stdout.trim()).toBe('"^W" vim-backward-kill-word');
});

it("deletes a Vim-style word immediately after recalling history", async () => {
  const scriptPath = join(
    tmpdir(),
    `dotkit-zle-${process.pid}-${Date.now()}.expect`,
  );
  const expectScript = String.raw`
    log_user 0
    set timeout 5
    spawn env TERM=xterm-256color zsh -f
    send -- "PS1='PROMPT> '; RPROMPT=''; source ${keysConfig}; bindkey -M viins '^P' up-history; capture-buffer() { print -r -- \"CAPTURE<\$BUFFER>\"; zle send-break }; zle -N capture-buffer; bindkey -M viins '^X' capture-buffer\r"
    expect "PROMPT> "
    send -- ": xxxxx-xxxxxx\r"
    expect "PROMPT> "
    send "\x10\x17\x18"
    expect {
      "CAPTURE<: xxxxx->" { exit 0 }
      timeout { exit 2 }
      eof { exit 3 }
    }
  `;

  await writeFile(scriptPath, expectScript);
  try {
    await expect(
      executeFile("/usr/bin/expect", [scriptPath]),
    ).resolves.toBeDefined();
  } finally {
    await rm(scriptPath, { force: true });
  }
});
