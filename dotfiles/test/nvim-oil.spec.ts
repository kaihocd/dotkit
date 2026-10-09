import { execFile } from "node:child_process";
import { resolve } from "node:path";
import { promisify } from "node:util";
import { expect, it } from "vitest";

it("rolls back Oil sessions and rejects opening from Cmdwin", async () => {
  const result = await promisify(execFile)(
    "nvim",
    [
      "--headless",
      "-u",
      "NONE",
      "-l",
      "dotfiles/configs/nvim/tests/oil-lifecycle.lua",
    ],
    { cwd: resolve(import.meta.dirname, "../.."), timeout: 10000 },
  );
  expect(result.stderr + result.stdout).toContain(
    "PASS Oil failed-open rollback",
  );
});
