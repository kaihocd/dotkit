import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const result = spawnSync(
  "nvim",
  ["--headless", "-u", "NONE", "-l", resolve(root, "tests/selection.lua")],
  {
    cwd: root,
    stdio: "inherit",
    timeout: 30_000,
  },
);

if (result.error) {
  console.error(result.error.message);
}

process.exit(result.status ?? 1);
