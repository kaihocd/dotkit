import { describe, expect, it } from "vitest";
import { createProjectContext } from "../src/context";
import type { WorkspaceProject } from "../src/types";

function project(name: string, directory: string): WorkspaceProject {
  return {
    name,
    directory,
    relativeDirectory: directory.replace("/workspace/", ""),
    scripts: {},
  };
}

const PROJECTS = [
  project("root", "/workspace"),
  project("configs", "/workspace/configs"),
  project("prism", "/workspace/packages/prism"),
];

describe("createProjectContext", () => {
  it("selects the workspace root project and excludes nested projects", () => {
    const context = createProjectContext("/workspace", "/workspace", PROJECTS);
    expect(context.project.name).toBe("root");
    expect(context.nestedProjects.map(({ name }) => name)).toEqual([
      "configs",
      "prism",
    ]);
  });

  it("selects the deepest project containing cwd", () => {
    const context = createProjectContext(
      "/workspace/packages/prism/src",
      "/workspace",
      PROJECTS,
    );
    expect(context.project.name).toBe("prism");
    expect(context.nestedProjects).toEqual([]);
  });
});
