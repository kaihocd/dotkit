import { allowsAction } from "./authorization";
import type {
  Installation,
  PlatformConfiguration,
  PlatformContext,
} from "../platform";
import type { DeploymentResult, ExecutionOptions, HookResult } from "./types";

export type {
  DeploymentResult,
  ExecutionAuthorization,
  ExecutionOptions,
  ExecutionStep,
  ExecutionStepStatus,
  HookResult,
} from "./types";
import { inspectInstallation } from "./inspection";
import { executeSoftware, unexecuted } from "./software";

/** Execution only: preview remains a separate read-only inspection path. */
export async function executeDeployment(
  platform: PlatformConfiguration,
  installation: Installation,
  options: ExecutionOptions,
): Promise<DeploymentResult> {
  if (!options.authorize.deployment) {
    throw new Error(
      "Deployment writes and platform hooks require explicit authorization.",
    );
  }
  if (platform.target !== installation.target)
    throw new Error("Platform and installation targets differ.");
  const plan = await inspectInstallation(installation, options);
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
  const steps = await executeSoftware(installation, options);
  if (platform.postInstall) {
    if (
      steps.some(
        (step) => step.status === "failed" || step.status === "blocked",
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

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
