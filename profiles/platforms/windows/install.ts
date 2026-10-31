import { execFile } from "node:child_process";
import { mkdir, writeFile } from "node:fs/promises";
import { join, resolve, win32 } from "node:path";
import { promisify } from "node:util";
import type { InstallationEnvironment } from "../../src/platform/environment";
import type { PlatformConfiguration } from "../../src/platform";
import { createChildEnvironment } from "../../src/platform/environment";
import {
  defineInstallations,
  type SoftwareInstallation,
} from "../../src/software";
import { winget } from "../../src/software/winget";
import { profileContent, profilePath } from "./profile";
import { prerequisite } from "./requirements";

const exec = promisify(execFile);
const repository = resolve(import.meta.dirname, "../../..");

const installations = defineInstallations("windows")({
  neovim: winget.install("Neovim.Neovim"),
  wezterm: winget.install("wez.wezterm.nightly"),
  starship: winget.install("Starship.Starship"),
  npm: prerequisite("where.exe", ["npm.cmd"]),
  treeSitterCli: winget.install("tree-sitter.tree-sitter-cli"),
  cCompiler: winget.install("Microsoft.VisualStudio.2022.BuildTools", [
    "--override",
    "--passive --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended",
  ]),
  git: winget.install("Git.Git"),
  curl: prerequisite("curl.exe", ["--version"]),
  ripgrep: winget.install("BurntSushi.ripgrep.MSVC"),
  fd: winget.install("sharkdp.fd"),
  fzf: winget.install("junegunn.fzf"),
  bat: winget.install("sharkdp.bat"),
  zoxide: winget.install("ajeetdsouza.zoxide"),
  powershell: winget.install("Microsoft.PowerShell"),
});

const configuration: PlatformConfiguration = {
  target: "windows",
  host: { platform: "win32" },
  environment: {
    defaults: {
      XDG_CONFIG_HOME: ".config",
      XDG_DATA_HOME: ".local/share",
      XDG_CACHE_HOME: ".cache",
      XDG_STATE_HOME: ".local/state",
    },
    binDirectory: ".local/bin",
  },
  software: (environment) => windowsSoftware(environment),
};

export function windowsSoftware(
  environment: InstallationEnvironment,
): readonly SoftwareInstallation[] {
  const sources = join(repository, "dotfiles/configs");
  const output = join(repository, "profiles/dist/windows");
  const profile = profilePath({
    cwd: repository,
    environment: createChildEnvironment(environment, process.env),
  });
  const config = environment.xdg.XDG_CONFIG_HOME;
  return [
    ...installations,
    {
      name: "palette",
      build: {
        requirements: { network: true, elevatedPrivileges: false },
        async run(context) {
          await exec(
            process.execPath,
            ["--import", "tsx", "packages/palette/scripts/ensure.ts"],
            { cwd: repository, env: context.environment },
          );
          await exec(
            process.execPath,
            ["--import", "tsx", "packages/palette/scripts/build.ts"],
            { cwd: repository, env: context.environment },
          );
        },
      },
      install: prerequisite("tar.exe", ["--version"]),
      links: [
        {
          source: join(repository, "packages/palette/dist"),
          target: join(environment.binDirectory, "palette"),
          type: "junction",
        },
      ],
    },
    {
      name: "windows-config",
      build: {
        requirements: { network: false, elevatedPrivileges: false },
        async run(context) {
          const actual = profilePath(context);
          if (
            win32.normalize(actual).toLowerCase() !==
            win32.normalize(profile).toLowerCase()
          ) {
            throw new Error(
              "PowerShell profile location changed; rerun deployment.",
            );
          }
          await mkdir(output, { recursive: true });
          await writeFile(
            join(output, "profile.ps1"),
            profileContent(environment),
            "utf8",
          );
        },
      },
      links: [
        {
          source: join(sources, "nvim"),
          target: join(config, "nvim"),
          type: "junction",
        },
        {
          source: join(sources, "wezterm"),
          target: join(config, "wezterm"),
          type: "junction",
        },
        {
          source: join(sources, "starship/starship.toml"),
          target: join(config, "starship.toml"),
          type: "file",
        },
        { source: join(output, "profile.ps1"), target: profile, type: "file" },
      ],
    },
  ];
}

export default configuration;
