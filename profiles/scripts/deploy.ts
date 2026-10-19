import { createInterface } from "node:readline/promises";
import { homedir } from "node:os";
import { resolve } from "node:path";
import { parseArgs } from "node:util";

import { resolveEnvironment } from "../src/deployment/environment";
import type { PlatformConfiguration } from "../src/deployment/platform";

import {
  discoverPlatforms,
  loadPlatform,
} from "../src/deployment/platform-discovery";
import {
  executeDeployment,
  type DeploymentResult,
} from "../src/deployment/execute";
import { previewDeployment } from "../src/deployment/preview";

export function selectPlatform(
  answer: string,
  names: readonly string[],
): string {
  const value = answer.trim();
  const index = /^[1-9]\d*$/.test(value) ? Number(value) - 1 : -1;
  const name = Number.isSafeInteger(index) ? names[index] : undefined;
  if (!name) throw new Error(`Choose a number from 1 to ${names.length}.`);
  return name;
}

export function deploymentStatus(
  result: DeploymentResult,
): "completed" | "failed" {
  return [...result.hooks, ...result.steps].every(
    ({ status }) => status === "completed" || status === "skipped",
  )
    ? "completed"
    : "failed";
}

async function choosePlatform(
  platforms: ReadonlyMap<string, string>,
): Promise<string> {
  const names = [...platforms.keys()];
  if (names.length === 0) throw new Error("No platform configurations found.");
  console.log("Available platforms:");
  names.forEach((name, index) => console.log(`  ${index + 1}. ${name}`));
  const readline = createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  try {
    const answer = await readline.question("Select a platform: ");
    return selectPlatform(answer, names);
  } finally {
    readline.close();
  }
}

async function main(): Promise<void> {
  const { values } = parseArgs({
    options: {
      home: { type: "string" },
      preview: { type: "boolean", default: false },
    },
    strict: true,
    allowPositionals: false,
  });
  const platforms = await discoverPlatforms();
  const platformName = await choosePlatform(platforms);
  const platform = await loadPlatform(platformName, platforms);
  if (platform.host && platform.host.platform !== process.platform) {
    throw new Error(
      `Platform "${platformName}" requires ${platform.host.platform}; current host is ${process.platform}.`,
    );
  }
  const home = values.home ?? homedir();
  const environment = resolveEnvironment({
    home,
    variables: process.env,
    defaults: Object.fromEntries(
      Object.entries(platform.environment.defaults).map(([name, value]) => [
        name,
        resolve(home, value),
      ]),
    ) as PlatformConfiguration["environment"]["defaults"],
    binDirectory: resolve(home, platform.environment.binDirectory),
  });
  const context = {
    cwd: resolve(import.meta.dirname, "../.."),
    environment,
    variables: process.env,
    onlyPreview: values.preview,
  };
  const installation = {
    target: platform.target,
    environment,
    software: platform.software(environment),
  };
  const options = {
    cwd: context.cwd,
    variables: process.env,
  };
  let status: "preview" | "completed" | "failed" = "preview";
  let result;
  if (values.preview) {
    result = await previewDeployment(platform, installation, options);
  } else {
    const execution = await executeDeployment(platform, installation, {
      ...options,
      authorize: {
        deployment: true,
        network: true,
        elevatedPrivileges: true,
      },
    });
    result = execution;
    status = deploymentStatus(execution);
    if (status === "failed") process.exitCode = 1;
  }
  console.log(
    JSON.stringify(
      {
        ...result,
        deployment: {
          status,
          platform: platformName,
        },
      },
      null,
      2,
    ),
  );
}

if (import.meta.main) {
  try {
    await main();
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}
