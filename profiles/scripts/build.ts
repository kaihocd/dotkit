import { mkdir, mkdtemp, rename, rm, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

import { success } from "@dotkit/shared/output";
import { runScript } from "@dotkit/shared/script";

import profiles from "../profiles.config";
import {
  createXdgEnvironmentScript,
  createXdgLaunchAgent,
  serializeLaunchAgent,
  XDG_LAUNCH_AGENT_LABEL,
} from "../src/macos/launch-agent";
import { validateXdg } from "../src/xdg";

const HELPER_NAME = "set-xdg-environment.sh";

export interface BuildOptions {
  readonly home?: string;
  readonly distributionDirectory?: string;
  readonly observe?: (event: BuildEvent) => void;
}

export interface BuildEvent {
  readonly type: "built";
  readonly distributionDirectory: string;
}

/** Builds the Profiles declaration into one LaunchAgent and its helper. */
export async function build({
  home = homedir(),
  distributionDirectory = resolve(import.meta.dirname, "..", "dist"),
  observe,
}: BuildOptions = {}): Promise<void> {
  const environment = validateXdg(profiles({ home }).xdg, home);
  const parent = dirname(distributionDirectory);
  await mkdir(parent, { recursive: true });
  const staging = await mkdtemp(join(parent, ".profiles-build-"));

  try {
    const helper = join(distributionDirectory, HELPER_NAME);
    const agent = createXdgLaunchAgent(helper);

    await Promise.all([
      writeFile(
        join(staging, HELPER_NAME),
        createXdgEnvironmentScript(environment),
        "utf8",
      ),
      writeFile(
        join(staging, `${XDG_LAUNCH_AGENT_LABEL}.plist`),
        serializeLaunchAgent(agent),
        "utf8",
      ),
    ]);

    await rm(distributionDirectory, { force: true, recursive: true });
    await rename(staging, distributionDirectory);
  } catch (error) {
    await rm(staging, { force: true, recursive: true });
    throw error;
  }

  observe?.({ type: "built", distributionDirectory });
}

if (import.meta.main) {
  await runScript(
    () =>
      build({
        observe: ({ distributionDirectory }) =>
          success(distributionDirectory, { label: "BUILD" }),
      }),
    { label: "PROFILES_ERROR" },
  );
}
