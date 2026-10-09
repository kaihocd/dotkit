import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const popup = resolve(
  process.env.POPUP_NVIM_PATH ?? resolve(root, "../popup.nvim"),
);
if (!existsSync(resolve(popup, "lua/popup/init.lua"))) {
  throw new Error("Set POPUP_NVIM_PATH to a popup.nvim checkout");
}

for (const test of [
  "select-numbering",
  "select-initial-highlights",
  "select-ui",
  "select-objects",
  "select-layout",
]) {
  const result = spawnSync(
    "nvim",
    ["--headless", "-u", "NONE", "-l", resolve(root, `tests/${test}.lua`)],
    {
      cwd: root,
      env: { ...process.env, POPUP_NVIM_PATH: popup },
      stdio: "inherit",
      timeout: 30_000,
    },
  );
  if (result.error) console.error(result.error.message);
  if (result.status !== 0) process.exit(result.status ?? 1);
}
