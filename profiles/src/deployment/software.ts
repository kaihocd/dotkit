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
