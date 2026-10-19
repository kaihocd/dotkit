import { readdir, stat } from "node:fs/promises";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import type { InstallationEnvironment, XdgEnvironment } from "./environment";
import type { SoftwareInstallation } from "../software";

export interface PlatformContext {
  readonly cwd: string;
  readonly environment: InstallationEnvironment;
  readonly variables: Readonly<Record<string, string | undefined>>;
  /** When true, callbacks must not write files or change service/session state. */
  readonly onlyPreview: boolean;
}

export type InstallationCallback = (context: PlatformContext) => Promise<void>;

export interface PlatformConfiguration {
  readonly target: string;
  readonly host?: { readonly platform: NodeJS.Platform };
  readonly environment: {
    readonly defaults: Readonly<Record<keyof XdgEnvironment, string>>;
    readonly binDirectory: string;
  };
  /** Validated with onlyPreview first, then executed before installation/build/linking. */
  readonly preInstall?: InstallationCallback;
  /** Runs only after all software steps succeed; never called by preview. */
  readonly postInstall?: InstallationCallback;
  readonly software: (
    environment: InstallationEnvironment,
  ) => readonly SoftwareInstallation[];
}

/** One platform owns its environment and its complete software declaration. */
export interface Installation {
  readonly target: string;
  readonly environment: InstallationEnvironment;
  readonly software: readonly SoftwareInstallation[];
}

/** Only direct platform directories with an install.ts entry are discoverable. */
export class PlatformLoader {
  constructor(
    private readonly directory = resolve(
      import.meta.dirname,
      "../../platforms",
    ),
  ) {}

  async discover(): Promise<ReadonlyMap<string, string>> {
    const directory = this.directory;
    const entries = await readdir(directory, { withFileTypes: true });
    const platforms = new Map<string, string>();
    for (const entry of entries.toSorted((a, b) =>
      a.name.localeCompare(b.name),
    )) {
      if (!entry.isDirectory()) continue;
      const file = join(directory, entry.name, "install.ts");
      try {
        // oxlint-disable-next-line no-await-in-loop
        if ((await stat(file)).isFile()) platforms.set(entry.name, file);
      } catch (error) {
        if (!(
          error instanceof Error &&
          "code" in error &&
          error.code === "ENOENT"
        ))
          throw error;
      }
    }
    return platforms;
  }

  /** Import only a discovered entry, never a path constructed from CLI input. */
  async load(
    name: string,
    platforms: ReadonlyMap<string, string>,
  ): Promise<PlatformConfiguration> {
    const file = platforms.get(name);
    if (!file) {
      throw new Error(
        `Unknown platform "${name}". Available: ${[...platforms.keys()].join(", ")}`,
      );
    }
    const module = await import(pathToFileURL(file).href);
    const configuration = module.default;
    if (!configuration || typeof configuration !== "object") {
      throw new TypeError(
        `Platform "${name}" must default-export a configuration object.`,
      );
    }
    return configuration as PlatformConfiguration;
  }
}
