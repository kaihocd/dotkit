import { defineInstallations } from "../../src/software";
import { execFile } from "node:child_process";
import { join, resolve } from "node:path";
import { promisify } from "node:util";

import type { InstallationEnvironment } from "../../src/platform/environment";
import type { PlatformConfiguration } from "../../src/platform";
import { pacman } from "../../src/software/pacman";
import { checkArch } from "./preflight";
import { publishEnvironment } from "./environment";

const repository = resolve(import.meta.dirname, "../../..");
const exec = promisify(execFile);

const installations = defineInstallations("archlinux")({
  neovim: pacman.install("neovim"),
  wezterm: pacman.install("wezterm"),
  starship: pacman.install("starship"),
  npm: pacman.install("npm"),
  treeSitterCli: pacman.install("tree-sitter-cli"),
  cCompiler: pacman.install("gcc"),
  git: pacman.install("git"),
  curl: pacman.install("curl"),
  unzip: pacman.install("unzip"),
  ripgrep: pacman.install("ripgrep"),
  fd: pacman.install("fd"),
  fzf: pacman.install("fzf"),
  bat: pacman.install("bat"),
  zoxide: pacman.install("zoxide"),
  zsh: pacman.install("zsh"),
  zshAutosuggestions: pacman.install("zsh-autosuggestions"),
  zshSyntaxHighlighting: pacman.install("zsh-syntax-highlighting"),
  zshHistorySubstringSearch: pacman.install("zsh-history-substring-search"),
  waylandClipboard: pacman.install("wl-clipboard"),
  fcitx5: pacman.install("fcitx5"),
  fcitx5Pinyin: pacman.install("fcitx5-chinese-addons"),
  fcitx5Configtool: pacman.install("fcitx5-configtool"),
  fcitx5Gtk: pacman.install("fcitx5-gtk"),
  fcitx5Qt: pacman.install("fcitx5-qt"),
  jetbrainsMonoFont: pacman.install("ttf-jetbrains-mono-nerd"),
  firaCodeFont: pacman.install("ttf-firacode-nerd"),
  symbolsFont: pacman.install("ttf-nerd-fonts-symbols-mono"),
  chineseFont: pacman.install("wqy-microhei"),
  cjkFont: pacman.install("noto-fonts-cjk"),
  emojiFont: pacman.install("noto-fonts-emoji"),
});

/** Platform configuration: environment defaults, software and their links. */
const configuration: PlatformConfiguration = {
  target: "archlinux",
  host: { platform: "linux" },
  preInstall: async (context) => {
    await publishEnvironment({ ...context, onlyPreview: true });
    await checkArch(context, configuration.software(context.environment));
  },
  postInstall: publishEnvironment,
  environment: {
    defaults: {
      XDG_CONFIG_HOME: ".config",
      XDG_DATA_HOME: ".local/share",
      XDG_CACHE_HOME: ".cache",
      XDG_STATE_HOME: ".local/state",
    },
    binDirectory: ".local/bin",
  },
  software: (environment: InstallationEnvironment) => {
    const home = environment.home;
    const config = environment.xdg.XDG_CONFIG_HOME;
    const sources = join(repository, "dotfiles/configs");
    return [
      ...installations,
      {
        name: "zsh",
        links: [
          {
            source: join(sources, "zsh/zshenv.zsh"),
            target: join(home, ".zshenv"),
          },
          {
            source: join(sources, "zsh/zshrc.zsh"),
            target: join(config, "zsh/.zshrc"),
          },
          {
            source: join(sources, "zsh/fzf.zsh"),
            target: join(config, "zsh/fzf.zsh"),
          },
          {
            source: join(sources, "zsh/keys.zsh"),
            target: join(config, "zsh/keys.zsh"),
          },
          {
            source: join(sources, "zsh/linux/tools.zsh"),
            target: join(config, "zsh/platform-tools.zsh"),
          },
          {
            source: join(sources, "zsh/tools.zsh"),
            target: join(config, "zsh/tools.zsh"),
          },
        ],
      },
      {
        name: "starship",
        links: [
          {
            source: join(sources, "starship/starship.toml"),
            target: join(config, "starship.toml"),
          },
        ],
      },
      {
        name: "neovim",
        links: [
          { source: join(sources, "nvim"), target: join(config, "nvim") },
        ],
      },
      {
        name: "wezterm",
        links: [
          { source: join(sources, "wezterm"), target: join(config, "wezterm") },
        ],
      },
      {
        name: "palette",
        build: {
          requirements: { network: true, elevatedPrivileges: false },
          async run(context) {
            const options = { cwd: repository, env: context.environment };
            await exec(
              process.execPath,
              ["--import", "tsx", "packages/palette/scripts/ensure.ts"],
              options,
            );
            await exec(
              process.execPath,
              ["--import", "tsx", "packages/palette/scripts/build.ts"],
              options,
            );
          },
        },
        links: [
          {
            source: join(repository, "packages/palette/dist/palette.js"),
            target: join(environment.binDirectory, "palette"),
          },
          {
            source: join(
              repository,
              "packages/palette/dist/completions/_palette",
            ),
            target: join(
              environment.xdg.XDG_DATA_HOME,
              "zsh/site-functions/_palette",
            ),
          },
        ],
      },
    ];
  },
};

export default configuration;
