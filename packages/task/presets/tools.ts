import { resolve } from "node:path";
import type { TaskDefinition } from "../src/types";
import { commandDefinition } from "./common";

/** Defines TypeScript checking for the current project's tsconfig. */
export function typecheck(): TaskDefinition {
  return commandDefinition("typecheck", (context) => ({
    executable: "pnpm",
    args: [
      "exec",
      "tsc",
      "--project",
      resolve(context.project.directory, "tsconfig.json"),
    ],
    cwd: context.project.directory,
  }));
}
