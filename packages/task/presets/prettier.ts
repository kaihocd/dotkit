import { resolve } from "node:path";
import type { TaskDefinition } from "../src/types";
import { commandDefinition, nestedPaths } from "./common";

/** Defines a Prettier task with workspace ignore and project ownership rules. */
export function prettier(mode: "check" | "fix"): TaskDefinition {
  const id = `prettier:${mode}`;
  return commandDefinition(id, (context) => ({
    executable: "pnpm",
    args: [
      "exec",
      "prettier",
      mode === "check" ? "--check" : "--write",
      "--ignore-path",
      resolve(context.workspace.directory, ".prettierignore"),
      ".",
      ...nestedPaths(context).map((path) => `!${path}/**`),
    ],
    cwd: context.project.directory,
  }));
}
