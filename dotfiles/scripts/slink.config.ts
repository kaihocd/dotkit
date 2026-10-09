import { homedir } from "node:os";
import { join, resolve } from "node:path";

import { requiredEnvironment } from "@dotkit/shared/environment";

const HOME = homedir();
const CONFIG_HOME = requiredEnvironment("XDG_CONFIG_HOME");
const PACKAGE_DIRECTORY = resolve(import.meta.dirname, "..");
const CONFIG_SOURCE = join(PACKAGE_DIRECTORY, "configs");
const ZSH_SOURCE = join(CONFIG_SOURCE, "zsh");

/** Symbolic links installed by Dotfiles, expressed as absolute paths. */
export const SLINK_CONFIG = [
  {
    source: join(ZSH_SOURCE, "zshenv.zsh"),
    target: join(HOME, ".zshenv"),
  },
  {
    source: join(ZSH_SOURCE, "zshrc.zsh"),
    target: join(CONFIG_HOME, "zsh/.zshrc"),
  },
  ...["fzf.zsh", "keys.zsh", "tools.zsh"].map((name) => ({
    source: join(ZSH_SOURCE, name),
    target: join(CONFIG_HOME, "zsh", name),
  })),
  {
    source: join(CONFIG_SOURCE, "starship/starship.toml"),
    target: join(CONFIG_HOME, "starship.toml"),
  },
  {
    source: join(CONFIG_SOURCE, "wezterm"),
    target: join(CONFIG_HOME, "wezterm"),
  },
  {
    source: join(CONFIG_SOURCE, "nvim"),
    target: join(CONFIG_HOME, "nvim"),
  },
] as const;
