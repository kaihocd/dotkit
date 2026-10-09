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

// Use an attached terminal so the popup can be inspected interactively.
const result = spawnSync(
  "nvim",
  ["-u", "NONE", "-i", "NONE", "-c", "luafile tests/demo-select.lua"],
  {
    cwd: root,
    env: { ...process.env, POPUP_NVIM_PATH: popup },
    stdio: "inherit",
  },
);

if (result.error) console.error(result.error.message);
process.exit(result.status ?? 1);
