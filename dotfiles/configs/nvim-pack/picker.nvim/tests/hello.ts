import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

// Resolve from the test file, not process.cwd(), so this works from the plugin root.
const root = resolve(import.meta.dirname, "..");
const script = `
local picker = require('picker')
assert(picker.hello() == 'hello from picker.nvim')
print(picker.hello())
vim.cmd('qa!')
`;

const result = spawnSync(
  "nvim",
  [
    "--headless",
    "-u",
    "NONE",
    "--cmd",
    `set rtp^=${root}`,
    "-c",
    `lua ${script.replaceAll("\n", " ")}`,
  ],
  { encoding: "utf8" },
);

process.stdout.write(result.stdout);
process.stderr.write(result.stderr);
process.exit(result.status ?? 1);
