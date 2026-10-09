import { describe, expect, it, vi } from "vitest";
import type { ProjectContext } from "../src/types";
import { TaskRunner } from "../src/runner";
import { TaskStore } from "../src/store";
import type { CommandFrame, CommandSpec, OutputChunk } from "../src/types";

const CONTEXT: ProjectContext = {
  cwd: "/workspace",
  project: {
    name: "root",
    directory: "/workspace",
    relativeDirectory: ".",
    scripts: {},
  },
  workspace: {
    directory: "/workspace",
    projects: [
      {
        name: "root",
        directory: "/workspace",
        relativeDirectory: ".",
        scripts: { check: "root" },
      },
      {
        name: "a",
        directory: "/workspace/a",
        relativeDirectory: "a",
        scripts: { check: "check" },
      },
      {
        name: "b",
        directory: "/workspace/b",
        relativeDirectory: "b",
        scripts: { check: "check" },
      },
      {
        name: "missing",
        directory: "/workspace/missing",
        relativeDirectory: "missing",
        scripts: {},
      },
    ],
  },
  nestedProjects: [
    {
      name: "a",
      directory: "/workspace/a",
      relativeDirectory: "a",
      scripts: { check: "check" },
    },
    {
      name: "b",
      directory: "/workspace/b",
      relativeDirectory: "b",
      scripts: { check: "check" },
    },
    {
      name: "missing",
      directory: "/workspace/missing",
      relativeDirectory: "missing",
      scripts: {},
    },
  ],
};

function frame(
  id: string,
  projectName: string,
  command: CommandSpec,
  exitCode = 0,
  output: readonly OutputChunk[] = [],
): CommandFrame {
  return {
    type: "command",
    id,
    projectName,
    command,
    output,
    result: { status: "exited", exitCode, signal: null },
    durationMs: 1,
  };
}

describe("TaskRunner", () => {
  it("runs top-level tasks sequentially and fails fast", async () => {
    const calls: string[] = [];
    const execute = vi.fn(
      async (id: string, projectName: string, command: CommandSpec) => {
        calls.push(id);
        return frame(id, projectName, command, id === "second" ? 1 : 0);
      },
    );
    const runner = new TaskRunner(new TaskStore(), execute);

    await expect(
      runner.run(
        [
          {
            type: "command",
            id: "first",
            command: { executable: "first", args: [], cwd: "/workspace" },
          },
          {
            type: "command",
            id: "second",
            command: { executable: "second", args: [], cwd: "/workspace" },
          },
          {
            type: "command",
            id: "third",
            command: { executable: "third", args: [], cwd: "/workspace" },
          },
        ],
        CONTEXT,
      ),
    ).rejects.toThrow('Task "second" failed');
    expect(calls).toEqual(["first", "second"]);
  });

  it("publishes a declaration-ordered workspace tree while packages settle concurrently", async () => {
    const releases = new Map<string, () => void>();
    const execute = vi.fn(
      (
        id: string,
        projectName: string,
        command: CommandSpec,
        observeOutput?: (chunk: OutputChunk) => void,
      ) =>
        new Promise<CommandFrame>((resolve) => {
          observeOutput?.({
            sequence: 0,
            stream: "stdout",
            data: new TextEncoder().encode(`from ${projectName}`),
          });
          releases.set(projectName, () =>
            resolve(
              frame(id, projectName, command, projectName === "a" ? 1 : 0),
            ),
          );
        }),
    );
    const store = new TaskStore();
    const runner = new TaskRunner(store, execute);
    const execution = runner.run(
      [
        {
          type: "workspace",
          id: "workspace:check",
          script: "check",
          arguments: ["--strict"],
        },
      ],
      CONTEXT,
    );

    await vi.waitFor(() => expect(releases.size).toBe(2));
    const running = store.snapshot();
    expect(running.nodes.get(1)?.children).toEqual([2, 3]);
    expect(running.nodes.get(2)?.status).toBe("running");
    expect(running.nodes.get(3)?.status).toBe("running");
    expect(
      [2, 3].map((id) =>
        Buffer.from(running.nodes.get(id)?.output[0]?.data ?? []).toString(),
      ),
    ).toEqual(["from a", "from b"]);

    releases.get("b")?.();
    releases.get("a")?.();
    await expect(execution).rejects.toThrow('Task "workspace:check" failed');

    const completed = store.snapshot();
    expect(completed.nodes.get(1)?.status).toBe("failed");
    expect(completed.nodes.get(2)?.status).toBe("failed");
    expect(completed.nodes.get(3)?.status).toBe("succeeded");
    expect(execute.mock.calls.map(([, , command]) => command.args)).toEqual([
      ["run", "check", "--strict"],
      ["run", "check", "--strict"],
    ]);
  });
});
