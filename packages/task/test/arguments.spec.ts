import { describe, expect, it } from "vitest";
import { parseArguments } from "../cli/arguments";

const CWD = "/workspace/project";

describe("parseArguments", () => {
  it("parses one comma-separated task list", () => {
    expect(parseArguments(["exec", "typecheck,prettier:check"], CWD)).toEqual({
      taskIds: ["typecheck", "prettier:check"],
      command: undefined,
    });
  });

  it("parses a workspace script and preserves all child arguments", () => {
    expect(
      parseArguments(["workspace", "slink", "--only-preview"], CWD),
    ).toEqual({
      workspace: {
        script: "slink",
        arguments: ["--only-preview"],
      },
    });
  });

  it("appends an opaque command without interpreting its arguments", () => {
    expect(
      parseArguments(
        [
          "exec",
          "prettier:check",
          "--name=extra",
          "--",
          "tsx",
          "scripts/check.ts",
          "--fix",
        ],
        CWD,
      ),
    ).toEqual({
      taskIds: ["prettier:check"],
      command: {
        type: "command",
        id: "extra",
        command: {
          executable: "tsx",
          args: ["scripts/check.ts", "--fix"],
          cwd: CWD,
        },
      },
    });
  });

  it("supports an opaque command without preset tasks", () => {
    const invocation = parseArguments(["exec", "--", "node", "--version"], CWD);
    expect("taskIds" in invocation).toBe(true);
    if (!("taskIds" in invocation)) return;
    expect(invocation.taskIds).toEqual([]);
    expect(invocation.command?.command.args).toEqual(["--version"]);
  });

  it("does not consume child-command help flags", () => {
    const invocation = parseArguments(["exec", "--", "node", "--help"], CWD);
    expect("taskIds" in invocation).toBe(true);
    if (!("taskIds" in invocation)) return;
    expect(invocation.command?.command.args).toEqual(["--help"]);
  });

  it("rejects the removed dry-run option", () => {
    expect(() =>
      parseArguments(["exec", "--dry-run", "typecheck"], CWD),
    ).toThrow('Unknown option "--dry-run"');
  });

  it.each([
    ["empty invocation", ["exec"]],
    ["workspace invocation without a script", ["workspace"]],
    ["multiple task-list operands", ["exec", "prettier:check", "oxlint:check"]],
    ["empty task ID", ["exec", "prettier:check,,oxlint:check"]],
    ["missing command", ["exec", "--"]],
  ])("rejects %s", (_, args) => {
    expect(() => parseArguments(args, CWD)).toThrow();
  });
});
