import type { InstallationEnvironment, XdgEnvironment } from "./environment";
import type { SoftwareInstallation } from "./software";

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
