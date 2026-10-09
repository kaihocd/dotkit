import { TaskError } from "../errors";
import type { TaskStateSource } from "../types";

/** Terminal capabilities available to Renderer implementations. */
export interface Terminal {
  readonly columns: number;
  readonly rows: number;
  write(data: string): void;
  clearLines(count: number): void;
  hideCursor(): void;
  showCursor(): void;
}

/** Lifecycle implemented by every Task Renderer. */
export interface TaskRenderer {
  attach(source: TaskStateSource): void;
  dispose(): void | Promise<void>;
}

/** Dependencies supplied when a Renderer is created. */
export interface RendererContext {
  readonly terminal: Terminal;
}

/** Named internal Renderer implementation available for selection. */
export interface TaskRendererDefinition {
  readonly id: string;
  create(context: RendererContext): TaskRenderer;
}

/** Resolves named internal Renderer definitions without coupling Task runtime. */
export class RendererRegistry {
  private readonly definitions = new Map<string, TaskRendererDefinition>();

  public constructor(definitions: readonly TaskRendererDefinition[]) {
    for (const definition of definitions) {
      if (this.definitions.has(definition.id)) {
        throw new TaskError(`Renderer ID repeated: "${definition.id}"`);
      }
      this.definitions.set(definition.id, definition);
    }
  }

  public create(id: string, context: RendererContext): TaskRenderer {
    const definition = this.definitions.get(id);
    if (!definition) throw new TaskError(`Unknown renderer "${id}"`);
    return definition.create(context);
  }
}
