import { describe, expect, it } from "vitest";
import { TASK_DEFINITIONS } from "../presets";
import { TaskRegistry } from "../src/registry";
import type { ProjectContext } from "../src/types";

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
    projects: [],
  },
  nestedProjects: [
    {
      name: "configs",
      directory: "/workspace/configs",
      relativeDirectory: "configs",
      scripts: {},
    },
  ],
};

const registry = new TaskRegistry(TASK_DEFINITIONS);

describe("preset definitions", () => {
  it("expands Prettier with the workspace ignore and project exclusions", () => {
    const [task] = registry.resolve(["prettier:check"], CONTEXT);
    expect(task).toMatchObject({
      type: "command",
      command: {
        cwd: "/workspace",
        args: [
          "exec",
          "prettier",
          "--check",
          "--ignore-path",
          "/workspace/.prettierignore",
          ".",
          "!configs/**",
        ],
      },
    });
  });

  it("finds a shared StyLua configuration in parent directories", () => {
    const [task] = registry.resolve(["stylua:check"], CONTEXT);
    expect(task).toMatchObject({
      type: "command",
      command: {
        cwd: "/workspace",
        args: [
          "exec",
          "stylua",
          "--check",
          "--search-parent-directories",
          ".",
          "--glob",
          "**/*.lua",
          "--glob",
          "!configs/**/*.lua",
        ],
      },
    });
  });

  it("expands Vitest into the current project", () => {
    expect(registry.resolve(["vitest"], CONTEXT)).toEqual([
      {
        type: "command",
        id: "vitest",
        command: {
          executable: "pnpm",
          args: ["exec", "vitest", "run", "--reporter=minimal"],
          cwd: "/workspace",
        },
      },
    ]);
  });

  it("rejects unknown full task IDs", () => {
    expect(() => registry.resolve(["prettier:unknown"], CONTEXT)).toThrow(
      'Unknown task "prettier:unknown"',
    );
  });
});
