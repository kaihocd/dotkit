import { stat } from "node:fs/promises";
import { symbolicLink } from "@dotkit/shared/link";
import type {
  Installation,
  PlatformConfiguration,
  PlatformContext,
} from "../platform";
import { createChildEnvironment } from "../platform/environment";
import {
  runInstallationCommand,
  type ActionRequirements,
  type InstallationCommand,
  type InstallationContext,
  type SoftwareInstallation,
} from "../software";
import { DeploymentInspector } from "./inspection";

export interface ExecutionAuthorization {
  /** Authorizes deployment writes and the platform's trusted callbacks. */
  readonly deployment: boolean;
  readonly network: boolean;
  readonly elevatedPrivileges: boolean;
}

/** Shared policy for preflight and action-time checks; never invokes sudo. */
function allowsAction(
  requirements: ActionRequirements,
  authorization: ExecutionAuthorization,
): boolean {
  return (
    authorization.deployment &&
    (!requirements.network || authorization.network) &&
    (!requirements.elevatedPrivileges || authorization.elevatedPrivileges)
  );
}

export interface ExecutionOptions {
  readonly cwd: string;
  readonly variables: Readonly<Record<string, string | undefined>>;
  readonly authorize: ExecutionAuthorization;
}

export type ExecutionStepStatus =
  "completed" | "skipped" | "blocked" | "failed" | "not-run";

export interface ExecutionStep {
  readonly software: string;
  readonly action: "install" | "build" | "links";
  readonly status: ExecutionStepStatus;
  readonly reason?: string;
}

export interface HookResult {
  readonly action: "preInstall" | "postInstall";
  readonly status: ExecutionStepStatus;
  readonly reason?: string;
}

export interface DeploymentResult {
  readonly hooks: HookResult[];
  readonly steps: readonly ExecutionStep[];
}

/** Owns one resolved deployment and its collaborators; results are local to each run. */
export class Deployment {
  private readonly inspector: DeploymentInspector;
  private readonly installer: SoftwareInstaller;
  private readonly options: Omit<ExecutionOptions, "authorize">;

  constructor(
    private readonly platform: PlatformConfiguration,
    private readonly installation: Installation,
    options: Omit<ExecutionOptions, "authorize">,
  ) {
    if (platform.target !== installation.target)
      throw new Error("Platform and installation targets differ.");
    this.options = {
      ...options,
      variables: Object.freeze({ ...options.variables }),
    };
    this.inspector = new DeploymentInspector(installation, this.options);
    this.installer = new SoftwareInstaller(installation, this.options);
  }

  async preview() {
    const { platform, installation, options } = this;
    let preInstall:
      { status: "checked" | "blocked"; reason?: string } | undefined;
    if (platform.preInstall) {
      try {
        await platform.preInstall({
          ...options,
          environment: installation.environment,
          onlyPreview: true,
        });
        preInstall = { status: "checked" };
      } catch (error) {
        preInstall = {
          status: "blocked",
          reason: error instanceof Error ? error.message : String(error),
        };
      }
    }
    const plan = await this.inspector.inspect();
    return {
      ...plan,
      hooks: {
        preInstall,
        postInstall: platform.postInstall
          ? {
              status: "not-run",
              reason:
                "Runs only after successful execution, not during preview.",
            }
          : undefined,
      },
    };
  }

  async run(authorize: ExecutionAuthorization): Promise<DeploymentResult> {
    const { platform, installation } = this;
    const options = { ...this.options, authorize };
    if (!options.authorize.deployment) {
      throw new Error(
        "Deployment writes and platform hooks require explicit authorization.",
      );
    }
    if (platform.target !== installation.target)
      throw new Error("Platform and installation targets differ.");
    const plan = await this.inspector.inspect();
    for (const entry of plan.software) {
      if (
        entry.installation?.status === "blocked" ||
        entry.links.some((link) => link.status === "blocked")
      ) {
        throw new Error(`Preflight blocked: ${entry.name}`);
      }
    }
    for (const entry of installation.software) {
      const inspected = plan.software.find((item) => item.name === entry.name)!;
      if (
        entry.install &&
        inspected.installation?.status === "missing" &&
        !allowsAction(entry.install.requirements, options.authorize)
      ) {
        throw new Error(
          `Installation requirements not authorized: ${entry.name}`,
        );
      }
      if (
        entry.build &&
        !allowsAction(entry.build.requirements, options.authorize)
      ) {
        throw new Error(`Build requirements not authorized: ${entry.name}`);
      }
    }
    const context: PlatformContext = {
      cwd: options.cwd,
      variables: options.variables,
      environment: installation.environment,
      onlyPreview: false,
    };
    const hooks: HookResult[] = [];
    if (platform.preInstall) {
      try {
        // The callback must validate its platform-specific targets without writes first.
        await platform.preInstall({ ...context, onlyPreview: true });
        await platform.preInstall(context);
        hooks.push({ action: "preInstall", status: "completed" });
      } catch (error) {
        hooks.push({
          action: "preInstall",
          status: "failed",
          reason: message(error),
        });
        if (platform.postInstall)
          hooks.push({
            action: "postInstall",
            status: "not-run",
            reason: "preInstall failed.",
          });
        return {
          hooks,
          steps: installation.software.flatMap((software) =>
            unexecuted(software, "preInstall failed."),
          ),
        };
      }
    }
    const steps = await this.installer.run(authorize);
    if (platform.postInstall) {
      if (
        steps.some(
          (result) => result.status === "failed" || result.status === "blocked",
        )
      ) {
        hooks.push({
          action: "postInstall",
          status: "not-run",
          reason: "Software deployment did not succeed.",
        });
      } else {
        try {
          await platform.postInstall(context);
          hooks.push({ action: "postInstall", status: "completed" });
        } catch (error) {
          hooks.push({
            action: "postInstall",
            status: "failed",
            reason: message(error),
          });
        }
      }
    }
    return { hooks, steps };
  }
}

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/** Executes software entries serially; each owns its install/build/links sequence. */
/* oxlint-disable no-await-in-loop */
class SoftwareInstaller {
  constructor(
    private readonly installation: Installation,
    private readonly options: Omit<ExecutionOptions, "authorize">,
  ) {}

  async run(
    authorize: ExecutionAuthorization,
  ): Promise<readonly ExecutionStep[]> {
    const installation = this.installation;
    const options = { ...this.options, authorize };
    if (!options.authorize.deployment)
      throw new Error("Deployment is not authorized.");
    const context = createContext(installation, options);
    const steps: ExecutionStep[] = [];

    for (const software of installation.software) {
      const start = steps.length;
      if (
        !software.install &&
        steps.some(
          (entry) =>
            entry.action === "install" &&
            entry.status !== "completed" &&
            entry.status !== "skipped",
        )
      ) {
        steps.push(
          ...unexecuted(
            software,
            "Required software preparation did not succeed.",
          ),
        );
        continue;
      }
      try {
        if (software.install) {
          const command = software.install.command(context);
          const state = await software.install.inspect(context);
          if (state.status === "blocked") {
            steps.push(step(software, "install", "blocked", state.reason));
            continue;
          }
          if (state.status === "missing") {
            const result = await runInstall(
              software,
              command,
              options.authorize,
              context,
            );
            steps.push(result);
            if (result.status !== "completed") continue;
          } else {
            steps.push(
              step(software, "install", "skipped", "Already installed."),
            );
          }
        }

        if (software.build) {
          if (!allowsAction(software.build.requirements, options.authorize)) {
            steps.push(
              step(
                software,
                "build",
                "blocked",
                "Build requirements are not authorized.",
              ),
            );
            continue;
          }
          try {
            await software.build.run(context);
            if (await hasMissingSource(software))
              throw new Error("Build completed without required link sources.");
            steps.push(step(software, "build", "completed"));
          } catch (error) {
            steps.push(step(software, "build", "failed", message(error)));
            continue;
          }
        }

        try {
          if (await hasMissingSource(software))
            throw new Error("Link source is missing or dangling.");
          await symbolicLink(software.links);
          steps.push(step(software, "links", "completed"));
        } catch (error) {
          steps.push(step(software, "links", "failed", message(error)));
        }
      } catch (error) {
        const action =
          actions(software).find(
            (candidate) =>
              !steps
                .slice(start)
                .some((recorded) => recorded.action === candidate),
          ) ?? "links";
        steps.push(step(software, action, "failed", message(error)));
      } finally {
        const recorded = new Set(
          steps.slice(start).map(({ action }) => action),
        );
        steps.push(
          ...unexecuted(
            software,
            "An earlier step failed or was blocked.",
          ).filter(({ action }) => !recorded.has(action)),
        );
      }
    }
    return steps;
  }
}
/* oxlint-enable no-await-in-loop */

function actions(software: SoftwareInstallation): ExecutionStep["action"][] {
  return [
    ...(software.install ? ["install" as const] : []),
    ...(software.build ? ["build" as const] : []),
    "links",
  ];
}

function unexecuted(
  software: SoftwareInstallation,
  reason: string,
): ExecutionStep[] {
  return actions(software).map((action) =>
    step(software, action, "not-run", reason),
  );
}

function step(
  software: SoftwareInstallation,
  action: ExecutionStep["action"],
  status: ExecutionStepStatus,
  reason?: string,
): ExecutionStep {
  return {
    software: software.name,
    action,
    status,
    ...(reason ? { reason } : {}),
  };
}

function createContext(
  installation: Installation,
  options: ExecutionOptions,
): InstallationContext {
  return {
    cwd: options.cwd,
    environment: createChildEnvironment(
      installation.environment,
      options.variables,
    ),
  };
}

async function runInstall(
  software: SoftwareInstallation,
  command: InstallationCommand,
  authorization: ExecutionAuthorization,
  context: InstallationContext,
): Promise<ExecutionStep> {
  if (!allowsAction(software.install!.requirements, authorization))
    return step(
      software,
      "install",
      "blocked",
      "Install requirements are not authorized.",
    );
  try {
    await runInstallationCommand(command);
    const state = await software.install!.inspect(context);
    if (state.status !== "installed")
      throw new Error(`Post-install verification failed: ${state.status}`);
    return step(software, "install", "completed");
  } catch (error) {
    return step(software, "install", "failed", message(error));
  }
}

/* oxlint-disable no-await-in-loop */
async function hasMissingSource(
  software: SoftwareInstallation,
): Promise<boolean> {
  for (const link of software.links) {
    try {
      await stat(link.source);
    } catch (error) {
      if (error instanceof Error && "code" in error && error.code === "ENOENT")
        return true;
      throw error;
    }
  }
  return false;
}
/* oxlint-enable no-await-in-loop */
