import type { TaskDefinition } from "../src/types";
import { commandDefinition, nestedPaths } from "./common";

/** Defines a Stylua task restricted to project-owned Lua files. */
export function stylua(mode: "check" | "fix"): TaskDefinition {
  const id = `stylua:${mode}`;
  return commandDefinition(id, (context) => ({
    executable: "pnpm",
    args: [
      "exec",
      "stylua",
      ...(mode === "check" ? ["--check"] : []),
      "--search-parent-directories",
      ".",
      "--glob",
      "**/*.lua",
      ...nestedPaths(context).flatMap((path) => [
        "--glob",
        `!${path}/**/*.lua`,
      ]),
    ],
    cwd: context.project.directory,
  }));
}
