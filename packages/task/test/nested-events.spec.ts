import { describe, expect, it } from "vitest";
import { NestedEventClient, NestedEventServer } from "../src/nested-events";
import { TaskStore } from "../src/store";

function parentStore(): TaskStore {
  const store = new TaskStore();
  store.dispatch({
    type: "workspace-started",
    runId: 1,
    id: "workspace:check",
    script: "check",
    packageCount: 2,
    startedAt: 0,
  });
  store.dispatch({
    type: "command-started",
    runId: 2,
    parentRunId: 1,
    id: "@dotkit/task check",
    projectName: "@dotkit/task",
    command: { executable: "pnpm", args: ["run", "check"], cwd: "/workspace" },
    startedAt: 0,
  });
  return store;
}

describe("nested Task events", () => {
  it("imports a nested command under its package with isolated identity and output", async () => {
    const outerStore = parentStore();
    const server = new NestedEventServer(outerStore);
    await server.start();

    const innerStore = new TaskStore();
    const previous = {
      socket: process.env.DOTKIT_TASK_EVENT_SOCKET,
      token: process.env.DOTKIT_TASK_EVENT_TOKEN,
    };
    Object.assign(process.env, server.environment(2));
    const client = await NestedEventClient.connectFromEnvironment();
    expect(client).toBeDefined();
    client!.attach(innerStore);

    innerStore.dispatch({
      type: "command-started",
      runId: 1,
      id: "typecheck",
      projectName: "@dotkit/task",
      command: { executable: "tsc", args: ["--noEmit"], cwd: "/workspace" },
      startedAt: 10,
    });
    innerStore.dispatch({
      type: "command-output",
      runId: 1,
      chunk: {
        sequence: 0,
        stream: "stdout",
        data: new TextEncoder().encode("checked\n"),
      },
    });
    innerStore.dispatch({
      type: "command-finished",
      runId: 1,
      frame: {
        type: "command",
        id: "typecheck",
        projectName: "@dotkit/task",
        command: { executable: "tsc", args: ["--noEmit"], cwd: "/workspace" },
        output: [],
        result: { status: "exited", exitCode: 0, signal: null },
        durationMs: 20,
      },
      finishedAt: 30,
    });
    await client!.dispose();

    await expect.poll(() => outerStore.snapshot().nodes.size).toBe(3);
    const outer = outerStore.snapshot();
    const importedId = outer.nodes.get(2)?.children[0];
    expect(importedId).toBeDefined();
    expect(importedId).not.toBe(1);
    expect(outer.nodes.get(importedId!)).toMatchObject({
      parentRunId: 2,
      id: "typecheck",
      status: "succeeded",
      durationMs: 20,
    });
    expect(
      Buffer.from(
        outer.nodes.get(importedId!)?.output[0]?.data ?? [],
      ).toString(),
    ).toBe("checked\n");

    if (previous.socket === undefined)
      delete process.env.DOTKIT_TASK_EVENT_SOCKET;
    else process.env.DOTKIT_TASK_EVENT_SOCKET = previous.socket;
    if (previous.token === undefined)
      delete process.env.DOTKIT_TASK_EVENT_TOKEN;
    else process.env.DOTKIT_TASK_EVENT_TOKEN = previous.token;
    await server.dispose();
  });
});
