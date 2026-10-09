import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const fff = resolve(
  process.env.FFF_NVIM_PATH ??
    resolve(homedir(), ".local/share/nvim/site/pack/core/opt/fff"),
);
const devicons = resolve(
  process.env.DEVICONS_NVIM_PATH ??
    resolve(
      homedir(),
      ".local/share/nvim/site/pack/core/opt/nvim-web-devicons",
    ),
);
const popup = resolve(
  process.env.POPUP_NVIM_PATH ?? resolve(root, "../popup.nvim"),
);
if (
  !existsSync(resolve(fff, "lua/fff.lua")) &&
  !existsSync(resolve(fff, "lua/fff/init.lua"))
) {
  throw new Error(
    "Set FFF_NVIM_PATH to the fff plugin root (not its lua directory)",
  );
}
if (!existsSync(resolve(popup, "lua/popup/init.lua")))
  throw new Error("Set POPUP_NVIM_PATH to popup.nvim");
const result = spawnSync(
  "nvim",
  ["-u", "NONE", "-i", "NONE", "-c", "luafile tests/demo-picker-fff.lua"],
  {
    cwd: root,
    env: {
      ...process.env,
      FFF_NVIM_PATH: fff,
      POPUP_NVIM_PATH: popup,
      DEVICONS_NVIM_PATH: existsSync(
        resolve(devicons, "lua/nvim-web-devicons.lua"),
      )
        ? devicons
        : "",
      PICKER_DEMO_CWD: resolve(process.argv[2] ?? root),
    },
    stdio: "inherit",
  },
);
if (result.error) console.error(result.error.message);
process.exit(result.status ?? 1);
