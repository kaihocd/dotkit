import { afterEach, describe, expect, it, vi } from "vitest";
import type { Terminal } from "../src/rendering/core";
import { PlainTreeRenderer } from "../src/rendering/renderers/plain";
import { InteractiveTreeRenderer } from "../src/rendering/renderers/tree/renderer";
import { TaskStore } from "../src/store";
import type { CommandFrame, OutputChunk } from "../src/types";

class MemoryTerminal implements Terminal {
  public readonly writes: string[] = [];
  public readonly clears: number[] = [];
  public hidden = false;

  public constructor(
    public readonly columns = 120,
    public readonly rows = 24,
  ) {}

  public write(data: string): void {
    this.writes.push(data);
  }

  public clearLines(count: number): void {
    this.clears.push(count);
  }

  public hideCursor(): void {
    this.hidden = true;
  }

  public showCursor(): void {
    this.hidden = false;
  }
}

function output(data: string, sequence = 0): OutputChunk {
  return {
    sequence,
    stream: "stdout",
    data: new TextEncoder().encode(data),
  };
}

function commandFrame(
  id: string,
  projectName: string,
  chunks: readonly OutputChunk[],
  exitCode = 0,
): CommandFrame {
  return {
    type: "command",
    id,
    projectName,
    command: { executable: "tool", args: [], cwd: "/workspace" },
    output: chunks,
    result: { status: "exited", exitCode, signal: null },
    durationMs: 438,
  };
}

function dispatchWorkspace(store: TaskStore): void {
  store.dispatch({
    type: "workspace-started",
    runId: 1,
    id: "workspace:check",
    script: "check",
    packageCount: 2,
    startedAt: 0,
  });
}

function startCommand(
  store: TaskStore,
  runId: number,
  projectName: string,
): void {
  store.dispatch({
    type: "command-started",
    runId,
    parentRunId: 1,
    id: `${projectName} check`,
    projectName,
    command: { executable: "tool", args: [], cwd: "/workspace" },
    startedAt: 0,
  });
}

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllEnvs();
});

describe("PlainTreeRenderer", () => {
  it("retains successful and failed command output", () => {
    vi.stubEnv("FORCE_COLOR", "0");
    const terminal = new MemoryTerminal();
    const store = new TaskStore();
    const renderer = new PlainTreeRenderer(terminal);
    renderer.attach(store);

    for (const [runId, id, exitCode] of [
      [1, "passing-tests", 0],
      [2, "failing-tests", 1],
    ] as const) {
      const command = {
        executable: "vitest",
        args: ["run"],
        cwd: "/workspace",
      };
      const chunk = output(`${id} output\n`);
      store.dispatch({
        type: "command-started",
        runId,
        id,
        projectName: "root",
        command,
        startedAt: 0,
      });
      store.dispatch({ type: "command-output", runId, chunk });
      store.dispatch({
        type: "command-finished",
        runId,
        frame: {
          ...commandFrame(id, "root", [], exitCode),
          command,
        },
        finishedAt: 438,
      });
    }

    const rendered = terminal.writes.join("");
    expect(rendered).toContain("passing-tests output");
    expect(rendered).toContain("failing-tests output");
    renderer.dispose();
  });

  it("prints each completed package as one contiguous block", () => {
    vi.stubEnv("FORCE_COLOR", "0");
    const terminal = new MemoryTerminal();
    const store = new TaskStore();
    const renderer = new PlainTreeRenderer(terminal);
    renderer.attach(store);

    dispatchWorkspace(store);
    startCommand(store, 2, "a");
    startCommand(store, 3, "b");
    store.dispatch({
      type: "command-output",
      runId: 2,
      chunk: output("a1\na2\n"),
    });
    store.dispatch({
      type: "command-output",
      runId: 3,
      chunk: output("b1\nb2\n"),
    });
    store.dispatch({
      type: "command-finished",
      runId: 3,
      frame: commandFrame("b check", "b", [output("b1\nb2\n")]),
      finishedAt: 438,
    });
    store.dispatch({
      type: "command-finished",
      runId: 2,
      frame: commandFrame("a check", "a", [output("a1\na2\n")]),
      finishedAt: 438,
    });
    renderer.dispose();

    const rendered = terminal.writes.join("");
    expect(rendered.indexOf("b1\n  b2")).toBeLessThan(
      rendered.indexOf("a1\n  a2"),
    );
    expect(rendered).toContain("✓ b check  438ms");
    expect(rendered).toContain("✓ a check  438ms");
  });
});

describe("InteractiveTreeRenderer", () => {
  it.each([0, 1])(
    "commits standalone task blocks and the package result (exit %i)",
    (exitCode) => {
      vi.stubEnv("FORCE_COLOR", "0");
      const terminal = new MemoryTerminal(120, 4);
      const store = new TaskStore();
      const renderer = new InteractiveTreeRenderer(terminal);
      renderer.attach(store);

      for (const [runId, id, startedAt, chunks] of [
        [1, "typecheck", 0, []],
        [2, "vitest", 500, [output("first\n\nsecond\nthird\nfourth\nfifth\n")]],
      ] as const) {
        store.dispatch({
          type: "command-started",
          runId,
          id,
          projectName: "dotfiles",
          command: { executable: "tool", args: [], cwd: "/workspace" },
          startedAt,
        });
        for (const chunk of chunks)
          store.dispatch({ type: "command-output", runId, chunk });
        store.dispatch({
          type: "command-finished",
          runId,
          frame: commandFrame(
            id,
            "dotfiles",
            chunks,
            runId === 2 ? exitCode : 0,
          ),
          finishedAt: startedAt + 438,
        });
      }
      renderer.dispose();
      const result = exitCode === 0 ? "Done in" : "Exited with code 1 after";
      expect(terminal.writes).toContain("[dotfiles]\n");
      expect(terminal.writes).toContain("│  [typecheck]  Done in 438ms\n");
      expect(terminal.writes).toContain(
        [
          "│  [vitest]",
          "│  │  first",
          "│  │",
          "│  │  second",
          "│  │  third",
          "│  │  fourth",
          "│  │  fifth",
          `│  └─ ${result} 438ms`,
          "",
        ].join("\n"),
      );
      expect(terminal.writes.at(-1)).toBe(`└─ ${result} 938ms\n`);
      const count = terminal.writes.length;
      renderer.dispose();
      expect(terminal.writes).toHaveLength(count);
      expect(terminal.hidden).toBe(false);
    },
  );

  it("colors only each package identity and tracks with a distinct stable color", () => {
    vi.useFakeTimers();
    vi.stubEnv("FORCE_COLOR", "1");
    const terminal = new MemoryTerminal();
    const store = new TaskStore();
    const renderer = new InteractiveTreeRenderer(terminal);
    renderer.attach(store);

    dispatchWorkspace(store);
    startCommand(store, 2, "alpha");
    startCommand(store, 3, "beta");

    const workspaceStart = terminal.writes[0]!;
    const live = terminal.writes.at(-1)!;
    const ESCAPE = "\u001B";
    const styledSpan = new RegExp(
      `${ESCAPE}\\[([0-9;]+)m(.*?)${ESCAPE}\\[([0-9;]+)m`,
      "gu",
    );
    const workspaceSpans = [...workspaceStart.matchAll(styledSpan)];
    expect(workspaceSpans.map((match) => match[2])).toEqual([
      "[workspace:check]",
      "│",
    ]);
    expect(workspaceSpans[0]?.[1]).not.toBe(workspaceSpans[1]?.[1]);

    const spans = [...live.matchAll(styledSpan)];
    expect(spans.map((match) => match[2])).toEqual([
      "│",
      "[alpha]",
      "│",
      "└─",
      "Running   ",
      "│",
      "│",
      "[beta]",
      "│",
      "└─",
      "Running   ",
      "│",
      "└─",
      "0 of 2 packages completed",
    ]);

    const alphaColor = spans.find((match) => match[2] === "[alpha]")?.[1];
    const betaColor = spans.find((match) => match[2] === "[beta]")?.[1];
    expect(alphaColor).toBeDefined();
    expect(betaColor).toBeDefined();
    expect(alphaColor).not.toBe(betaColor);
    expect(live).not.toContain(" check");
    const grayColor = spans[0]?.[1];
    const runningColors = spans
      .filter((match) => match[2]?.startsWith("Running"))
      .map((match) => match[1]);
    expect(new Set(runningColors)).toEqual(new Set([grayColor]));
    expect(grayColor).not.toBe(alphaColor);
    expect(grayColor).not.toBe(betaColor);
    expect(
      spans
        .filter((match) => ["│", "└─"].includes(match[2] ?? ""))
        .some((match) => match[1] === grayColor),
    ).toBe(true);

    const nested = commandFrame("typecheck", "alpha", []);
    store.dispatch({
      type: "command-started",
      runId: 4,
      parentRunId: 2,
      id: "typecheck",
      projectName: "alpha",
      command: nested.command,
      startedAt: 0,
    });
    const nestedLive = terminal.writes.at(-1)!;
    const nestedLiveSpans = [...nestedLive.matchAll(styledSpan)];
    const taskColor = nestedLiveSpans.find(
      (match) => match[2] === "[typecheck]",
    )?.[1];
    expect(taskColor).toBe(alphaColor);
    expect(nestedLiveSpans.find((match) => match[2] === "›")?.[1]).toBe(
      grayColor,
    );

    const rawOutput = output(
      "\u001B[1;31mraw\u001B[0m output\u001B[2J\u001B]0;unsafe\u0007\n",
    );
    store.dispatch({ type: "command-output", runId: 4, chunk: rawOutput });
    vi.advanceTimersByTime(50);
    const liveOutput = terminal.writes.at(-1)!;
    expect(liveOutput).toContain("\u001B[1;31mraw\u001B[0m output");
    expect(liveOutput).not.toContain("\u001B[2J");
    expect(liveOutput).not.toContain("\u001B]0;unsafe");
    const nestedFrame = commandFrame("typecheck", "alpha", [rawOutput]);
    store.dispatch({
      type: "command-finished",
      runId: 4,
      frame: nestedFrame,
      finishedAt: 438,
    });
    const frame = commandFrame("alpha check", "alpha", []);
    store.dispatch({
      type: "command-finished",
      runId: 2,
      frame,
      finishedAt: 438,
    });
    const committed = terminal.writes.at(-2)!;
    expect(committed).toContain("\u001B[1;31mraw\u001B[0m output");
    expect(committed).not.toContain("\u001B[2J");
    expect(committed).not.toContain("\u001B]0;unsafe");
    const committedSpans = [...committed.matchAll(styledSpan)];
    expect(committedSpans.map((match) => match[2])).toEqual([
      "│",
      "[alpha]",
      "│",
      "│",
      "[typecheck]",
      "│",
      "│",
      "│",
      "raw",
      "│",
      "│",
      "└─",
      "Done in 438ms",
      "│",
      "└─",
      "Done in 438ms",
      "│",
    ]);
    expect(
      committedSpans.find((match) => match[2] === "[typecheck]")?.[1],
    ).toBe(taskColor);
    expect(
      committedSpans
        .filter((match) => ["[alpha]", "│", "└─"].includes(match[2] ?? ""))
        .some((match) => match[1] === alphaColor),
    ).toBe(true);
    expect(
      committedSpans
        .filter((match) => match[1] === grayColor)
        .every((match) => ["│", "├─", "└─"].includes(match[2] ?? "")),
    ).toBe(true);
    const successColor = committedSpans.at(-1)?.[1];
    expect(successColor).not.toBe(alphaColor);

    const failure = commandFrame("beta check", "beta", [], 1);
    store.dispatch({
      type: "command-finished",
      runId: 3,
      frame: failure,
      finishedAt: 438,
    });
    const failedBlock = terminal.writes.at(-2)!;
    const failedSpans = [...failedBlock.matchAll(styledSpan)];
    const failedResult = failedSpans.find(
      (match) => match[2] === "Exited with code 1 after 438ms",
    );
    expect(failedResult).toBeDefined();
    const failureColor = failedResult?.[1];
    expect(failureColor).not.toBe(betaColor);
    expect(failureColor).not.toBe(successColor);

    store.dispatch({
      type: "workspace-finished",
      runId: 1,
      frame: {
        type: "workspace",
        id: "workspace:check",
        script: "check",
        packages: [frame, failure],
        durationMs: 438,
      },
      finishedAt: 438,
    });
    const resultSpans = [...terminal.writes.at(-1)!.matchAll(styledSpan)];
    expect(resultSpans.map((match) => match[2])).toEqual([
      "└─",
      "1 package failed, 1 passed in 438ms",
    ]);
    expect(resultSpans[0]?.[1]).toBe(grayColor);
    expect(resultSpans[1]?.[1]).toBe(failureColor);
    renderer.dispose();
  });

  it("shows live output for a top-level command node", () => {
    vi.useFakeTimers();
    vi.stubEnv("FORCE_COLOR", "0");
    const terminal = new MemoryTerminal();
    const store = new TaskStore();
    const renderer = new InteractiveTreeRenderer(terminal);
    renderer.attach(store);

    store.dispatch({
      type: "command-started",
      runId: 1,
      id: "renderer-smoke",
      projectName: "root",
      command: { executable: "tool", args: [], cwd: "/workspace" },
      startedAt: 0,
    });
    store.dispatch({
      type: "command-output",
      runId: 1,
      chunk: output("first\nsecond\n"),
    });

    vi.advanceTimersByTime(50);
    const live = terminal.writes.at(-1);
    expect(live).toBe(
      [
        "│  [renderer-smoke]",
        "│  │  first",
        "│  │  second",
        "│  └─ Running   ",
        "└─ Running   ",
        "",
      ].join("\n"),
    );
    expect(
      terminal.writes.filter((write) => write === "[root]\n"),
    ).toHaveLength(1);
    vi.advanceTimersByTime(350);
    expect(terminal.writes.at(-1)).toContain("\n└─ Running.  \n");
    store.dispatch({
      type: "command-finished",
      runId: 1,
      frame: commandFrame("renderer-smoke", "root", [
        output("first\nsecond\n"),
      ]),
      finishedAt: 438,
    });
    // The package is still active between tasks, even with no running command.
    expect(terminal.writes.at(-1)).toBe("└─ Running.  \n");
    renderer.dispose();
    expect(terminal.writes.at(-1)).toBe("└─ Done in 438ms\n");
  });

  it("shows scoped live details for every running workspace package", () => {
    vi.useFakeTimers();
    vi.stubEnv("FORCE_COLOR", "0");
    const terminal = new MemoryTerminal();
    const store = new TaskStore();
    const renderer = new InteractiveTreeRenderer(terminal, {
      liveOutputLines: 2,
      spinnerIntervalMs: 80,
    });
    renderer.attach(store);

    dispatchWorkspace(store);
    startCommand(store, 2, "a");
    startCommand(store, 3, "b");
    store.dispatch({
      type: "command-output",
      runId: 2,
      chunk: output("a1\na2\n\na3\n"),
    });
    store.dispatch({
      type: "command-output",
      runId: 3,
      chunk: output("b1\nb2\n"),
    });

    const writesBeforeFlush = terminal.writes.length;
    vi.advanceTimersByTime(50);
    const details = terminal.writes.at(-1);
    vi.advanceTimersByTime(30);
    const afterTick = terminal.writes.at(-1);

    expect(terminal.writes.length).toBe(writesBeforeFlush + 2);
    expect(details).toBe(
      [
        "│  [a]",
        "│  │  … 1 earlier lines",
        "│  │  a2",
        "│  │  a3",
        "│  └─ Running   ",
        "│",
        "│  [b]",
        "│  │  b1",
        "│  │  b2",
        "│  └─ Running   ",
        "│",
        "└─ 0 of 2 packages completed",
        "",
      ].join("\n"),
    );
    expect(details).not.toContain("a1");
    expect(afterTick).toContain("└─ Running.  ");
    expect(terminal.clears.some((count) => count > 0)).toBe(true);
    expect(terminal.hidden).toBe(true);

    renderer.dispose();
    expect(terminal.hidden).toBe(false);
  });

  it("renders the deepest active nested task instead of package process noise", () => {
    vi.useFakeTimers();
    vi.stubEnv("FORCE_COLOR", "0");
    const terminal = new MemoryTerminal();
    const store = new TaskStore();
    const renderer = new InteractiveTreeRenderer(terminal);
    renderer.attach(store);

    dispatchWorkspace(store);
    startCommand(store, 2, "a");
    store.dispatch({
      type: "command-started",
      runId: 3,
      parentRunId: 2,
      id: "typecheck",
      projectName: "a",
      command: { executable: "tsc", args: ["--noEmit"], cwd: "/workspace" },
      startedAt: 0,
    });
    store.dispatch({
      type: "command-output",
      runId: 3,
      chunk: output("checking types\n"),
    });
    vi.advanceTimersByTime(50);

    expect(terminal.writes.at(-1)).toBe(
      [
        "│  [a] › [typecheck]",
        "│  │  checking types",
        "│  └─ Running   ",
        "│",
        "└─ 0 of 2 packages completed",
        "",
      ].join("\n"),
    );
    renderer.dispose();
  });

  it("renders every ancestor corner while only the deepest node animates", () => {
    vi.useFakeTimers();
    vi.stubEnv("FORCE_COLOR", "0");
    const terminal = new MemoryTerminal();
    const store = new TaskStore();
    const renderer = new InteractiveTreeRenderer(terminal, {
      spinnerIntervalMs: 80,
    });
    renderer.attach(store);

    dispatchWorkspace(store);
    startCommand(store, 2, "a");
    store.dispatch({
      type: "command-started",
      runId: 3,
      parentRunId: 2,
      id: "check",
      projectName: "a",
      command: { executable: "task", args: [], cwd: "/workspace" },
      startedAt: 0,
    });
    store.dispatch({
      type: "command-started",
      runId: 4,
      parentRunId: 3,
      id: "typecheck",
      projectName: "a",
      command: { executable: "tsc", args: [], cwd: "/workspace" },
      startedAt: 0,
    });

    const firstFrame = terminal.writes.at(-1)!;
    expect(firstFrame).toContain(
      ["│  [a] › [check] › [typecheck]", "│  └─ Running   "].join("\n"),
    );

    vi.advanceTimersByTime(80);
    const nextFrame = terminal.writes.at(-1)!;
    expect(nextFrame).toContain("│  └─ Running.  ");
    expect(nextFrame.match(/Running\./g)).toHaveLength(1);
    expect(nextFrame.match(/└─ Running$/gm)).toBeNull();
    renderer.dispose();
  });

  it("keeps the package corner while waiting for the next nested task", () => {
    vi.useFakeTimers();
    vi.stubEnv("FORCE_COLOR", "0");
    const terminal = new MemoryTerminal();
    const store = new TaskStore();
    const renderer = new InteractiveTreeRenderer(terminal);
    renderer.attach(store);

    dispatchWorkspace(store);
    startCommand(store, 2, "a");
    store.dispatch({
      type: "command-output",
      runId: 2,
      chunk: output("> task exec typecheck,oxlint:check\n"),
    });
    const nested = commandFrame("typecheck", "a", [output("checked\n")]);
    store.dispatch({
      type: "command-started",
      runId: 3,
      parentRunId: 2,
      id: "typecheck",
      projectName: "a",
      command: nested.command,
      startedAt: 0,
    });
    store.dispatch({
      type: "command-output",
      runId: 3,
      chunk: nested.output[0]!,
    });
    store.dispatch({
      type: "command-finished",
      runId: 3,
      frame: nested,
      finishedAt: 438,
    });

    expect(terminal.writes.at(-1)).toBe(
      [
        "│  [a] › [typecheck]",
        "│  │  checked",
        "│  └─ Running   ",
        "│",
        "└─ 0 of 2 packages completed",
        "",
      ].join("\n"),
    );
    expect(terminal.writes.at(-1)).not.toContain("task exec");
    renderer.dispose();
  });

  it("persists a completed nested task inside its package block", () => {
    vi.useFakeTimers();
    vi.stubEnv("FORCE_COLOR", "0");
    const terminal = new MemoryTerminal();
    const store = new TaskStore();
    const renderer = new InteractiveTreeRenderer(terminal);
    renderer.attach(store);

    dispatchWorkspace(store);
    startCommand(store, 2, "a");
    const nested = commandFrame("typecheck", "a", [output("checked\n")]);
    store.dispatch({
      type: "command-started",
      runId: 3,
      parentRunId: 2,
      id: "typecheck",
      projectName: "a",
      command: nested.command,
      startedAt: 0,
    });
    store.dispatch({
      type: "command-output",
      runId: 3,
      chunk: nested.output[0]!,
    });
    store.dispatch({
      type: "command-finished",
      runId: 3,
      frame: nested,
      finishedAt: 438,
    });
    expect(
      terminal.writes.some((write) =>
        write.startsWith("│  [typecheck]\n│  │  checked"),
      ),
    ).toBe(false);
    const packageFrame = commandFrame("a check", "a", []);
    store.dispatch({
      type: "command-finished",
      runId: 2,
      frame: packageFrame,
      finishedAt: 438,
    });

    expect(terminal.writes.at(-2)).toContain(
      [
        "│  [a]",
        "│  │  [typecheck]",
        "│  │  │  checked",
        "│  │  └─ Done in 438ms",
        "│  └─ Done in 438ms",
      ].join("\n"),
    );
    renderer.dispose();
  });

  it("retains successful and failed nested command output", () => {
    vi.useFakeTimers();
    vi.stubEnv("FORCE_COLOR", "0");
    const terminal = new MemoryTerminal();
    const store = new TaskStore();
    const renderer = new InteractiveTreeRenderer(terminal);
    renderer.attach(store);

    dispatchWorkspace(store);
    startCommand(store, 2, "a");
    for (const [runId, id, exitCode] of [
      [3, "passing-tests", 0],
      [4, "failing-tests", 1],
    ] as const) {
      const frame: CommandFrame = {
        ...commandFrame(id, "a", [output(`${id} output\n`)], exitCode),
        command: {
          executable: "vitest",
          args: ["run"],
          cwd: "/workspace",
        },
      };
      store.dispatch({
        type: "command-started",
        runId,
        parentRunId: 2,
        id,
        projectName: "a",
        command: frame.command,
        startedAt: 0,
      });
      store.dispatch({
        type: "command-output",
        runId,
        chunk: frame.output[0]!,
      });
      store.dispatch({
        type: "command-finished",
        runId,
        frame,
        finishedAt: 438,
      });
    }
    store.dispatch({
      type: "command-finished",
      runId: 2,
      frame: commandFrame("a check", "a", [], 1),
      finishedAt: 438,
    });

    const committed = terminal.writes.at(-2)!;
    expect(committed).toContain("passing-tests output");
    expect(committed).toContain("failing-tests output");
    renderer.dispose();
  });

  it("compresses completed leaves without output onto one line", () => {
    vi.useFakeTimers();
    vi.stubEnv("FORCE_COLOR", "0");
    const terminal = new MemoryTerminal();
    const store = new TaskStore();
    const renderer = new InteractiveTreeRenderer(terminal);
    renderer.attach(store);

    dispatchWorkspace(store);
    startCommand(store, 2, "a");
    const nested = commandFrame("typecheck", "a", []);
    store.dispatch({
      type: "command-started",
      runId: 3,
      parentRunId: 2,
      id: "typecheck",
      projectName: "a",
      command: nested.command,
      startedAt: 0,
    });
    store.dispatch({
      type: "command-finished",
      runId: 3,
      frame: nested,
      finishedAt: 438,
    });
    store.dispatch({
      type: "command-finished",
      runId: 2,
      frame: commandFrame("a check", "a", []),
      finishedAt: 438,
    });

    expect(terminal.writes.at(-2)).toContain(
      [
        "│  [a]",
        "│  │  [typecheck]  Done in 438ms",
        "│  └─ Done in 438ms",
      ].join("\n"),
    );
    renderer.dispose();
  });

  it("bounds the transient Dashboard to the terminal viewport", () => {
    vi.useFakeTimers();
    vi.stubEnv("FORCE_COLOR", "0");
    const terminal = new MemoryTerminal(120, 8);
    const store = new TaskStore();
    const renderer = new InteractiveTreeRenderer(terminal);
    renderer.attach(store);

    dispatchWorkspace(store);
    for (let runId = 2; runId <= 6; runId += 1) {
      startCommand(store, runId, `package-${runId}`);
      store.dispatch({
        type: "command-output",
        runId,
        chunk: output("one\ntwo\nthree\nfour\n"),
      });
    }
    vi.advanceTimersByTime(50);

    const dashboard = terminal.writes.at(-1)!;
    expect(dashboard.split("\n").length - 1).toBeLessThanOrEqual(7);
    expect(dashboard).toContain("earlier dashboard lines");
    expect(dashboard).toContain("0 of 2 packages completed");
    expect(terminal.clears.every((count) => count <= 7)).toBe(true);
    renderer.dispose();
  });

  it("preserves SGR styling, strips terminal controls, and truncates live details", () => {
    vi.useFakeTimers();
    vi.stubEnv("FORCE_COLOR", "0");
    const terminal = new MemoryTerminal(24);
    const store = new TaskStore();
    const renderer = new InteractiveTreeRenderer(terminal);
    renderer.attach(store);

    dispatchWorkspace(store);
    startCommand(store, 2, "a");
    store.dispatch({
      type: "command-output",
      runId: 2,
      chunk: output(
        "\u001B[31mabcdefghijklmnopqrstuvwxyz\u001B[0m\u001B[2J\u001B]0;unsafe\u0007\n",
      ),
    });
    vi.advanceTimersByTime(50);

    const details = terminal.writes.at(-1);
    expect(details).toContain("│  │  \u001B[31mabcdefghijklmnop…\u001B[0m");
    expect(details).not.toContain("\u001B[2J");
    expect(details).not.toContain("\u001B]0;unsafe");
    renderer.dispose();
  });

  it("wraps persistent output without truncating it on narrow terminals", () => {
    vi.useFakeTimers();
    vi.stubEnv("FORCE_COLOR", "0");
    const terminal = new MemoryTerminal(24);
    const store = new TaskStore();
    const renderer = new InteractiveTreeRenderer(terminal);
    renderer.attach(store);

    dispatchWorkspace(store);
    startCommand(store, 2, "a");
    const failure = commandFrame(
      "a check",
      "a",
      [output("\u001B[1;31mabcdefghijklmnopqrstuvwxyz\u001B[0m\n")],
      1,
    );
    store.dispatch({
      type: "command-output",
      runId: 2,
      chunk: failure.output[0]!,
    });
    store.dispatch({
      type: "command-finished",
      runId: 2,
      frame: failure,
      finishedAt: 438,
    });

    const committed = terminal.writes.at(-2)!;
    expect(committed).toContain(
      [
        "│  │  \u001B[1;31mabcdefghijklmnopq\u001B[0m",
        "│  │  \u001B[1;31mrstuvwxyz\u001B[0m",
      ].join("\n"),
    );
    expect(committed).not.toContain("…");
    const SGR = new RegExp(`${"\u001B"}\\[[0-9;]*m`, "gu");
    for (const line of committed.split("\n")) {
      expect([...line.replaceAll(SGR, "")].length).toBeLessThanOrEqual(24);
    }
    renderer.dispose();
  });

  it("commits each completed package log once and prints only a final summary", () => {
    vi.useFakeTimers();
    vi.stubEnv("FORCE_COLOR", "0");
    const terminal = new MemoryTerminal();
    const store = new TaskStore();
    const renderer = new InteractiveTreeRenderer(terminal);
    renderer.attach(store);

    dispatchWorkspace(store);
    startCommand(store, 2, "success");
    startCommand(store, 3, "failure");
    const success = commandFrame("success check", "success", [
      output("hidden\n"),
    ]);
    const failure = commandFrame(
      "failure check",
      "failure",
      [output("reason\n")],
      1,
    );
    store.dispatch({
      type: "command-output",
      runId: 2,
      chunk: success.output[0]!,
    });
    store.dispatch({
      type: "command-output",
      runId: 3,
      chunk: failure.output[0]!,
    });
    store.dispatch({
      type: "command-finished",
      runId: 2,
      frame: success,
      finishedAt: 438,
    });
    expect(terminal.writes.at(-1)).toContain("└─ 1 of 2 packages completed\n");
    store.dispatch({
      type: "command-finished",
      runId: 3,
      frame: failure,
      finishedAt: 438,
    });
    store.dispatch({
      type: "workspace-finished",
      runId: 1,
      frame: {
        type: "workspace",
        id: "workspace:check",
        script: "check",
        packages: [success, failure],
        durationMs: 438,
      },
      finishedAt: 438,
    });

    const rendered = terminal.writes.join("");
    expect(rendered).toContain(
      ["│  [success]", "│  │  hidden", "│  └─ Done in 438ms", "│", ""].join(
        "\n",
      ),
    );
    expect(rendered).toContain(
      [
        "│  [failure]",
        "│  │  reason",
        "│  └─ Exited with code 1 after 438ms",
        "│",
        "",
      ].join("\n"),
    );
    expect(
      terminal.writes.filter((write) => write.includes("└─ Done in 438ms")),
    ).toHaveLength(1);
    expect(
      terminal.writes.filter((write) =>
        write.includes("└─ Exited with code 1 after 438ms"),
      ),
    ).toHaveLength(1);
    expect(terminal.writes[0]).toBe("[workspace:check]\n│\n");
    expect(terminal.writes.at(-1)).toBe(
      "└─ 1 package failed, 1 passed in 438ms\n",
    );
    renderer.dispose();
  });

  it("commits concurrent packages in completion order while summarizing in declaration order", () => {
    vi.useFakeTimers();
    vi.stubEnv("FORCE_COLOR", "0");
    const terminal = new MemoryTerminal();
    const store = new TaskStore();
    const renderer = new InteractiveTreeRenderer(terminal);
    renderer.attach(store);

    dispatchWorkspace(store);
    startCommand(store, 2, "a");
    startCommand(store, 3, "b");
    const a = commandFrame("a check", "a", [output("a failed\n")], 2);
    const b = commandFrame("b check", "b", [output("b failed\n")], 3);
    for (const [runId, failed] of [
      [3, b],
      [2, a],
    ] as const) {
      store.dispatch({
        type: "command-output",
        runId,
        chunk: failed.output[0]!,
      });
      store.dispatch({
        type: "command-finished",
        runId,
        frame: failed,
        finishedAt: 438,
      });
    }
    store.dispatch({
      type: "workspace-finished",
      runId: 1,
      frame: {
        type: "workspace",
        id: "workspace:check",
        script: "check",
        packages: [a, b],
        durationMs: 438,
      },
      finishedAt: 438,
    });

    const committed = terminal.writes.filter((write) =>
      write.includes("after 438ms"),
    );
    expect(committed).toHaveLength(2);
    expect(committed[0]).toContain("│  [b]");
    expect(committed[1]).toContain("│  [a]");
    expect(committed[0]).toContain("│  │  b failed");
    expect(committed[1]).toContain("│  │  a failed");
    expect(terminal.writes.at(-1)).toBe(
      "└─ 2 packages failed, 0 passed in 438ms\n",
    );
    renderer.dispose();
  });
});
