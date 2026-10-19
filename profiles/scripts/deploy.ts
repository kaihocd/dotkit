import { createInterface } from "node:readline/promises";
import { homedir } from "node:os";
import { resolve } from "node:path";
import { parseArgs } from "node:util";

import {
  Deployment,
  PlatformLoader,
  resolveEnvironment,
  type PlatformConfiguration,
  type DeploymentResult,
} from "../src";

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
  const loader = new PlatformLoader();
  const platforms = await loader.discover();
  const platformName = await choosePlatform(platforms);
  const platform = await loader.load(platformName, platforms);
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
  const deployment = new Deployment(platform, installation, options);
  if (values.preview) {
    printPreview(await deployment.preview());
    return;
  }
  const execution = await deployment.run({
    deployment: true,
    network: true,
    elevatedPrivileges: true,
  });
  const status = deploymentStatus(execution);
  printExecution(execution, status);
  if (status === "failed") process.exitCode = 1;
}

if (import.meta.main) {
  try {
    await main();
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}

type Preview = Awaited<ReturnType<Deployment["preview"]>>;

function printPreview(report: Preview): void {
  console.log(`\nPreview: ${report.target}\nHome: ${report.environment.home}`);
  const missing = report.software.filter(
    (entry) => entry.installation?.status === "missing",
  );
  const installed = report.software.filter(
    (entry) => entry.installation?.status === "installed",
  );
  console.log(`\nInstalled: ${installed.length} packages`);
  console.log(
    `To install (${missing.length}): ${missing.map((entry) => entry.name).join(", ") || "none"}`,
  );
  const builds = report.software.filter((entry) => entry.build);
  console.log(
    `To build: ${builds.map((entry) => entry.name).join(", ") || "none"}`,
  );
  if (report.target === "archlinux") {
    console.log(
      `\nUser environment: ${report.environment.home}/.config/environment.d/60-dotkit.conf`,
    );
    console.log(
      "After successful deployment: reload and verify systemd user environment; desktop logout/login required.",
    );
  }
  console.log("\nConfiguration links:");
  for (const entry of report.software) {
    for (const link of entry.links) {
      console.log(`  [${link.status}] ${link.target}`);
      if (link.status === "blocked") console.log(`    ${link.reason}`);
    }
    if (entry.installation?.status === "blocked")
      console.log(`  BLOCKED ${entry.name}: ${entry.installation.reason}`);
  }
  if (report.hooks.preInstall?.status === "blocked")
    console.log(`\nBLOCKED: ${report.hooks.preInstall.reason}`);
  if (report.target === "archlinux" && missing.length)
    console.log(
      "\nExecution will request sudo and run one pacman full-upgrade/install transaction.",
    );
  console.log(
    "\nPreview only: no installation, builds or configuration writes performed.",
  );
}

function printExecution(result: DeploymentResult, status: string): void {
  console.log(`\nDeployment: ${status}`);
  for (const hook of result.hooks)
    console.log(
      `  [${hook.status}] ${hook.action}${hook.reason ? `: ${hook.reason}` : ""}`,
    );
  for (const step of result.steps)
    console.log(
      `  [${step.status}] ${step.software} / ${step.action}${step.reason ? `: ${step.reason}` : ""}`,
    );
}
