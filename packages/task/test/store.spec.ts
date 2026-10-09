import { describe, expect, it, vi } from "vitest";
import { TaskStore } from "../src/store";

describe("TaskStore", () => {
  it("publishes command output while its node is still running", () => {
    const store = new TaskStore();
    const observed: string[] = [];
    store.subscribe((tree, event) => {
      if (event.type === "command-output") {
        const node = tree.nodes.get(event.runId);
        observed.push(
          `${node?.status}:${Buffer.from(node?.output[0]?.data ?? []).toString()}`,
        );
      }
    });

    store.dispatch({
      type: "command-started",
      runId: 1,
      id: "typecheck",
      projectName: "@dotkit/task",
      command: { executable: "tsc", args: [], cwd: "/workspace" },
      startedAt: 10,
    });
    store.dispatch({
      type: "command-output",
      runId: 1,
      chunk: {
        sequence: 0,
        stream: "stdout",
        data: new TextEncoder().encode("checking...\n"),
      },
    });

    expect(observed).toEqual(["running:checking...\n"]);
  });

  it("keeps concurrent package output in declaration-ordered child nodes", () => {
    const store = new TaskStore();
    store.dispatch({
      type: "workspace-started",
      runId: 1,
      id: "workspace:check",
      script: "check",
      packageCount: 2,
      startedAt: 0,
    });
    for (const [runId, name] of [
      [2, "a"],
      [3, "b"],
    ] as const) {
      store.dispatch({
        type: "command-started",
        runId,
        parentRunId: 1,
        id: `${name} check`,
        projectName: name,
        command: { executable: "pnpm", args: [], cwd: `/workspace/${name}` },
        startedAt: runId,
      });
    }
    store.dispatch({
      type: "command-output",
      runId: 3,
      chunk: {
        sequence: 0,
        stream: "stdout",
        data: new TextEncoder().encode("from b"),
      },
    });
    store.dispatch({
      type: "command-output",
      runId: 2,
      chunk: {
        sequence: 0,
        stream: "stdout",
        data: new TextEncoder().encode("from a"),
      },
    });

    const tree = store.snapshot();
    expect(tree.nodes.get(1)?.children).toEqual([2, 3]);
    expect(
      [2, 3].map((id) =>
        Buffer.from(tree.nodes.get(id)?.output[0]?.data ?? []).toString(),
      ),
    ).toEqual(["from a", "from b"]);
  });

  it("attaches a nested workspace without also exposing it as a root", () => {
    const store = new TaskStore();
    store.dispatch({
      type: "command-started",
      runId: 1,
      id: "package check",
      projectName: "package",
      command: { executable: "pnpm", args: [], cwd: "/workspace/package" },
      startedAt: 0,
    });
    store.dispatch({
      type: "workspace-started",
      runId: 2,
      parentRunId: 1,
      id: "nested workspace",
      script: "check",
      packageCount: 0,
      startedAt: 1,
    });

    expect(store.snapshot().roots).toEqual([1]);
    expect(store.snapshot().nodes.get(1)?.children).toEqual([2]);
  });

  it("allows subscribers to detach", () => {
    const store = new TaskStore();
    const subscriber = vi.fn();
    const unsubscribe = store.subscribe(subscriber);
    unsubscribe();
    store.dispatch({
      type: "workspace-started",
      runId: 1,
      id: "workspace:check",
      script: "check",
      packageCount: 0,
      startedAt: 0,
    });
    expect(subscriber).not.toHaveBeenCalled();
  });
});
