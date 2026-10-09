import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";

const root = resolve(import.meta.dirname, "..");
const runtime = spawnSync(
  "nvim",
  [
    "--headless",
    "-u",
    "NONE",
    "-c",
    "lua io.write(vim.env.VIMRUNTIME)",
    "-c",
    "qa!",
  ],
  { encoding: "utf8", timeout: 10_000 },
);
if (runtime.error || runtime.status !== 0)
  throw runtime.error ?? new Error(runtime.stderr);

const temporary = mkdtempSync(resolve(tmpdir(), "pack-luals-"));
let status = 1;
try {
  const config = JSON.parse(readFileSync(resolve(root, ".luarc.json"), "utf8"));
  config.workspace.library = [runtime.stdout.trim(), "${3rd}/luv/library"];
  const configPath = resolve(temporary, "config.json");
  writeFileSync(configPath, JSON.stringify(config));
  const result = spawnSync(
    "lua-language-server",
    ["--check=.", "--checklevel=Hint", `--configpath=${configPath}`],
    { cwd: root, stdio: "inherit", timeout: 60_000 },
  );
  if (result.error) console.error(result.error.message);
  status = result.status ?? 1;
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
process.exit(status);
