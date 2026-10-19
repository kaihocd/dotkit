import { allowsAction } from "./authorization";
import { execFile } from "node:child_process";
import { stat } from "node:fs/promises";
import { promisify } from "node:util";

import { symbolicLink } from "@dotkit/shared/link";

import type { Installation } from "../platform";
import { createChildEnvironment } from "../environment";
import type {
  InstallationCommand,
  InstallationContext,
  SoftwareInstallation,
} from "../software";
import type {
  ExecutionAuthorization,
  ExecutionOptions,
  ExecutionStep,
  ExecutionStepStatus,
} from "./types";

const execFileAsync = promisify(execFile);

/** Executes software entries serially; each owns its install/build/links sequence. */
/* oxlint-disable no-await-in-loop */
export async function executeSoftware(
  installation: Installation,
  options: ExecutionOptions,
): Promise<readonly ExecutionStep[]> {
  if (!options.authorize.deployment)
    throw new Error("Deployment is not authorized.");
  const context = createContext(installation, options);
  const steps: ExecutionStep[] = [];

  for (const software of installation.software) {
    const start = steps.length;
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
      const recorded = new Set(steps.slice(start).map(({ action }) => action));
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
/* oxlint-enable no-await-in-loop */

function actions(software: SoftwareInstallation): ExecutionStep["action"][] {
  return [
    ...(software.install ? ["install" as const] : []),
    ...(software.build ? ["build" as const] : []),
    "links",
  ];
}

export function unexecuted(
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
    await execFileAsync(command.executable, [...command.args], {
      cwd: command.cwd,
      env: command.environment,
    });
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

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
