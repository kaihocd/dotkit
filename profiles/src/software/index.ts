import { spawn } from "node:child_process";
import type { Link } from "@dotkit/shared/link";

/** A process invocation, never an arbitrary shell command string. */
export interface InstallationCommand {
  readonly executable: string;
  readonly args: readonly string[];
  readonly cwd: string;
  /** Explicit child environment; the executor must not mutate process.env. */
  readonly environment: Readonly<Record<string, string>>;
}

/** Effects must be visible before an action is authorized or executed. */
export interface ActionRequirements {
  readonly network: boolean;
  /** Elevated actions require authorization; no implicit sudo. */
  readonly elevatedPrivileges: boolean;
}

export type SoftwareState =
  | { readonly status: "installed" }
  | { readonly status: "missing" }
  | { readonly status: "blocked"; readonly reason: string };

export interface InstallationContext {
  readonly cwd: string;
  readonly environment: Readonly<Record<string, string>>;
}

export interface SoftwareInstall {
  /** Read-only probe. Must not install, update indexes or access the network. */
  readonly inspect: (context: InstallationContext) => Promise<SoftwareState>;
  /** Resolves a command without executing it. */
  readonly command: (context: InstallationContext) => InstallationCommand;
  readonly requirements: ActionRequirements;
}

export interface SoftwareBuild {
  /** Existing package-owned build implementation, invoked only during execution. */
  readonly run: (context: InstallationContext) => Promise<void>;
  readonly requirements: ActionRequirements;
}

/** Declaring an entry selects it; installation, build and links stay together. */
export interface SoftwareInstallation {
  readonly name: string;
  readonly install?: SoftwareInstall;
  readonly build?: SoftwareBuild;
  /** Absolute paths. Sources may be produced by this entry's build. */
  readonly links: readonly Link[];
}

/** Required capabilities only. Platform implementations own package names and commands. */
export const softwareCatalog = {
  common: [
    "neovim",
    "wezterm",
    "starship",
    "npm",
    "treeSitterCli",
    "cCompiler",
    "git",
    "curl",
    "unzip",
    "ripgrep",
    "fd",
    "fzf",
    "bat",
    "zoxide",
  ],
  platforms: {
    macos: ["zsh", "nvm", "zinit"],
    archlinux: [
      "zsh",
      "zshAutosuggestions",
      "zshSyntaxHighlighting",
      "zshHistorySubstringSearch",
      "waylandClipboard",
      "fcitx5",
      "fcitx5Pinyin",
      "fcitx5Configtool",
      "fcitx5Gtk",
      "fcitx5Qt",
      "jetbrainsMonoFont",
      "firaCodeFont",
      "symbolsFont",
      "chineseFont",
      "cjkFont",
      "emojiFont",
    ],
  },
} as const;

type Catalog = typeof softwareCatalog;
export type CatalogPlatform = keyof Catalog["platforms"];
export type SoftwareName<P extends CatalogPlatform> =
  Catalog["common"][number] | Catalog["platforms"][P][number];
export type Installations<P extends CatalogPlatform> = {
  readonly [Name in SoftwareName<P>]: SoftwareInstall;
};

export function defineInstallations<const P extends CatalogPlatform>(
  platform: P,
) {
  return <const T extends Installations<P>>(
    installs: T & Record<Exclude<keyof T, SoftwareName<P>>, never>,
  ): readonly SoftwareInstallation[] => {
    const names: readonly SoftwareName<P>[] = [
      ...softwareCatalog.common,
      ...softwareCatalog.platforms[platform],
    ];
    return names.map((name) => ({
      name: `software:${name}`,
      install: installs[name],
      links: [],
    }));
  };
}

/** Installation commands share the terminal for progress and explicit privilege prompts. */
export function runInstallationCommand(
  command: InstallationCommand,
): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn(command.executable, [...command.args], {
      cwd: command.cwd,
      env: command.environment,
      stdio: "inherit",
      shell: false,
    });
    child.once("error", reject);
    child.once("exit", (code, signal) => {
      if (code === 0) resolve();
      else
        reject(
          new Error(
            `${command.executable} ${signal ? `terminated by ${signal}` : `exited with code ${code}`}`,
          ),
        );
    });
  });
}
