import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
let status = 0;
for (const test of ["setup", "spec-merge"]) {
  const home = mkdtempSync(resolve(tmpdir(), "pack-test-"));
  try {
    const result = spawnSync(
      "nvim",
      ["--headless", "-u", "NONE", "-l", resolve(root, `tests/${test}.lua`)],
      {
        cwd: root,
        stdio: "inherit",
        timeout: 30_000,
        env: {
          ...process.env,
          NVIM_APPNAME: "nvim",
          PACK_TEST_HOME: home,
          XDG_CONFIG_HOME: resolve(home, "config"),
          XDG_DATA_HOME: resolve(home, "data"),
          XDG_STATE_HOME: resolve(home, "state"),
          XDG_CACHE_HOME: resolve(home, "cache"),
        },
      },
    );
    if (result.error) console.error(result.error.message);
    status = result.status ?? 1;
  } finally {
    rmSync(home, { recursive: true, force: true });
  }
  if (status !== 0) break;
}
process.exit(status);
