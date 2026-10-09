import type { ProjectContext } from "./types";
import { TaskError } from "./errors";
import type { TaskDefinition, TaskNode } from "./types";

/** Resolves complete Task IDs into structural nodes without executing them. */
export class TaskRegistry {
  private readonly definitions = new Map<string, TaskDefinition>();

  public constructor(definitions: readonly TaskDefinition[]) {
    for (const definition of definitions) {
      if (this.definitions.has(definition.id)) {
        throw new TaskError(`Task ID repeated: "${definition.id}"`);
      }
      this.definitions.set(definition.id, definition);
    }
  }

  public resolve(
    taskIds: readonly string[],
    context: ProjectContext,
  ): readonly TaskNode[] {
    return taskIds.map((taskId) => {
      const definition = this.definitions.get(taskId);
      if (!definition) {
        throw new TaskError(`Unknown task "${taskId}"`);
      }
      return definition.resolve(context);
    });
  }
}
