import { relative } from "node:path";
import type { ProjectContext } from "../src/types";
import type { CommandSpec, TaskDefinition } from "../src/types";

/** Builds a command Task definition from a context-aware command factory. */
export function commandDefinition(
  id: string,
  createCommand: (context: ProjectContext) => CommandSpec,
): TaskDefinition {
  return {
    id,
    resolve(context) {
      return { type: "command", id, command: createCommand(context) };
    },
  };
}

/** Returns nested package paths relative to the project being checked. */
export function nestedPaths(context: ProjectContext): readonly string[] {
  return context.nestedProjects.map(({ directory }) =>
    relative(context.project.directory, directory),
  );
}
