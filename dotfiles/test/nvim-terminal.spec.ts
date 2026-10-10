import { execFile } from "node:child_process";
import { resolve } from "node:path";
import { promisify } from "node:util";

import { expect, it } from "vitest";

it("manages terminal jobs without respawning on exit or leaking on shutdown", async () => {
  const { stderr } = await promisify(execFile)(
    "nvim",
    [
      "--headless",
      "-u",
      "NONE",
      "-l",
      "dotfiles/configs/nvim-pack/terminal.nvim/tests/lifecycle.lua",
    ],
    { cwd: resolve(import.meta.dirname, "../.."), timeout: 15000 },
  );
  expect(stderr.trim()).toBe("Terminal lifecycle checks passed");
});
