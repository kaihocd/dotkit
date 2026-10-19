import type {
  PlatformConfiguration,
  PlatformContext,
  Installation,
} from "./platform";
import { inspectInstallation } from "./execute/inspection";

/** Preview callbacks must be read-only. A failed callback must not hide software diagnostics. */
export async function previewDeployment(
  platform: PlatformConfiguration,
  installation: Installation,
  options: Pick<PlatformContext, "cwd" | "variables">,
) {
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
  const plan = await inspectInstallation(installation, options);
  return {
    ...plan,
    hooks: {
      preInstall,
      postInstall: platform.postInstall
        ? {
            status: "not-run",
            reason: "Runs only after successful execution, not during preview.",
          }
        : undefined,
    },
  };
}
