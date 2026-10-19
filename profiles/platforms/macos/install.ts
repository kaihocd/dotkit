import { execFile } from "node:child_process";
import { join, resolve } from "node:path";
import { promisify } from "node:util";

import type { InstallationEnvironment } from "../../src/deployment/environment";
import type { PlatformConfiguration } from "../../src/deployment/platform";
import { brew } from "../../src/package-managers/homebrew";
import { prepareXdgEnvironment, verifyXdgEnvironment } from "./launch-agent";

const repository = resolve(import.meta.dirname, "../../..");
const exec = promisify(execFile);

/** Platform configuration: environment defaults, software and their links. */
const configuration: PlatformConfiguration = {
  target: "macos",
  host: { platform: "darwin" },
  preInstall: prepareXdgEnvironment,
  postInstall: verifyXdgEnvironment,
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
      {
        name: "zsh",
        install: brew.install("zsh"),
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
            source: join(sources, "zsh/tools.zsh"),
            target: join(config, "zsh/tools.zsh"),
          },
        ],
      },
      {
        name: "starship",
        install: brew.install("starship"),
        links: [
          {
            source: join(sources, "starship/starship.toml"),
            target: join(config, "starship.toml"),
          },
        ],
      },
      {
        name: "neovim",
        install: brew.install("neovim"),
        links: [
          { source: join(sources, "nvim"), target: join(config, "nvim") },
        ],
      },
      {
        name: "wezterm",
        install: brew.install("wezterm@nightly", { kind: "cask" }),
        links: [
          { source: join(sources, "wezterm"), target: join(config, "wezterm") },
        ],
      },
      { name: "fzf", install: brew.install("fzf"), links: [] },
      { name: "bat", install: brew.install("bat"), links: [] },
      { name: "zoxide", install: brew.install("zoxide"), links: [] },
      { name: "nvm", install: brew.install("nvm"), links: [] },
      { name: "zinit", install: brew.install("zinit"), links: [] },
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
