#!/usr/bin/env tsx

import { runScript } from "@dotkit/shared/script";
import { TASK_DEFINITIONS } from "../presets";
import { discoverProjectContext } from "../src/context";
import { TaskFailedError } from "../src/errors";
import { NestedEventClient, NestedEventServer } from "../src/nested-events";
import { TaskRegistry } from "../src/registry";
import { createRenderer } from "../src/rendering";
import { TaskRunner } from "../src/runner";
import { TaskStore } from "../src/store";
import { parseArguments } from "./arguments";

const HELP = `Usage:
  task exec <task-id[,task-id...]>
  task exec [--name=<name>] [task-id[,task-id...]] -- <command> [arguments...]
  task workspace <script> [arguments...]

Examples:
  task exec typecheck,oxlint:check,prettier:check
  task exec -- tsx scripts/sync.ts
  task workspace check
  task workspace slink --only-preview
`;

async function runTasks(
  tasks: Parameters<TaskRunner["run"]>[0],
  context: Parameters<TaskRunner["run"]>[1],
): Promise<void> {
  const store = new TaskStore();
  const nestedClient = await NestedEventClient.connectFromEnvironment();
  if (nestedClient) {
    nestedClient.attach(store);
    try {
      await new TaskRunner(store).run(tasks, context);
    } finally {
      await nestedClient.dispose();
    }
    return;
  }

  const renderer = createRenderer();
  const nestedServer = new NestedEventServer(store);
  await nestedServer.start();
  renderer.attach(store);
  try {
    await new TaskRunner(store, undefined, (parentRunId) =>
      nestedServer.environment(parentRunId),
    ).run(tasks, context);
  } finally {
    renderer.dispose();
    await nestedServer.dispose();
  }
}

async function main(): Promise<void> {
  const invocation = parseArguments(process.argv.slice(2));
  if ("help" in invocation) {
    process.stdout.write(HELP);
    return;
  }

  const context = await discoverProjectContext();
  if ("workspace" in invocation) {
    await runTasks(
      [
        {
          type: "workspace",
          id: `workspace:${invocation.workspace.script}`,
          script: invocation.workspace.script,
          arguments: invocation.workspace.arguments,
        },
      ],
      context,
    );
    return;
  }

  const registry = new TaskRegistry(TASK_DEFINITIONS);
  const tasks = [...registry.resolve(invocation.taskIds, context)];
  if (invocation.command) {
    tasks.push(invocation.command);
  }

  await runTasks(tasks, context);
}

await runScript(
  async () => {
    try {
      await main();
    } catch (error) {
      if (error instanceof TaskFailedError) {
        process.exitCode = 1;
        return;
      }
      throw error;
    }
  },
  { label: "TASK_ERROR" },
);
