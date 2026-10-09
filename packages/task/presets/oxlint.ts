import type { TaskDefinition } from "../src/types";
import { commandDefinition, nestedPaths } from "./common";

/** Defines an Oxlint task with nested package exclusions. */
export function oxlint(mode: "check" | "fix"): TaskDefinition {
  const id = `oxlint:${mode}`;
  return commandDefinition(id, (context) => ({
    executable: "pnpm",
    args: [
      "exec",
      "oxlint",
      ...(mode === "fix" ? ["--fix"] : []),
      "--no-error-on-unmatched-pattern",
      ".",
      ...nestedPaths(context).flatMap((path) => [
        "--ignore-pattern",
        `${path}/**`,
      ]),
    ],
    cwd: context.project.directory,
  }));
}
