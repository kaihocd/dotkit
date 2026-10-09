import { execFile } from "node:child_process";
import { resolve } from "node:path";
import { promisify } from "node:util";

import { expect, it } from "vitest";

it.each([["popup-placement", "PASS popup placement"]])(
  "checks %s behavior",
  async (script, output) => {
    const configs = resolve(import.meta.dirname, "../configs");
    const { stderr } = await promisify(execFile)("nvim", [
      "--headless",
      "-u",
      "NONE",
      `+set rtp+=${configs}/nvim,${configs}/nvim-pack/popup.nvim`,
      `+luafile ${configs}/nvim/tests/${script}.lua`,
      "+qa!",
    ]);
    expect(stderr.trim()).toBe(output);
  },
);

it("checks the current Picker Select behavior", async () => {
  const root = resolve(import.meta.dirname, "../configs/nvim-pack/picker.nvim");
  const { stderr } = await promisify(execFile)(
    "nvim",
    ["--headless", "-u", "NONE", "-l", resolve(root, "tests/select.lua")],
    { cwd: root, timeout: 30_000 },
  );
  expect(stderr.trim()).toMatch(/(?:^|\n)Passed \d+ tests$/);
});
