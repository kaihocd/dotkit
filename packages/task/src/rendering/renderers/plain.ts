import { stripVTControlCharacters } from "node:util";
import type { TaskEvent, TaskStateSource, TaskStateTree } from "../../types";
import type { TaskRenderer, Terminal } from "../core";
import {
  duration,
  frameSucceeded,
  persistentOutput,
  styled,
  type Style,
} from "../output";

function writeIndentedOutput(
  write: (data: string) => void,
  output: readonly string[],
  indent: string,
): void {
  for (const line of output) write(`${indent}${line}\n`);
}

/** Stable append-only Renderer for CI, pipes, and redirected output. */
export class PlainTreeRenderer implements TaskRenderer {
  private unsubscribe?: () => void;

  public constructor(private readonly terminal: Terminal) {}

  private readonly write = (data: string): void => {
    this.terminal.write(stripVTControlCharacters(data));
  };

  public attach(source: TaskStateSource): void {
    this.unsubscribe?.();
    this.unsubscribe = source.subscribe((tree, event) =>
      this.render(tree, event),
    );
  }

  public dispose(): void {
    this.unsubscribe?.();
    this.unsubscribe = undefined;
  }

  private render(tree: TaskStateTree, event: TaskEvent): void {
    switch (event.type) {
      case "workspace-started":
        this.write(`${styled("●", "cyan")} ${styled(event.id, "bold")}\n\n`);
        break;
      case "command-started":
        this.write(`  ${styled("●", "cyan")} ${styled(event.id, "bold")}\n`);
        break;
      case "command-output":
        break;
      case "command-finished": {
        const node = tree.nodes.get(event.runId);
        if (node) writeIndentedOutput(this.write, persistentOutput(node), "  ");
        const passed = frameSucceeded(event.frame);
        const symbol = passed ? "✓" : "✗";
        const style: Style = passed ? "green" : "red";
        this.write(
          `  ${styled(symbol, style)} ${styled(event.frame.id, style)}  ${styled(duration(event.frame.durationMs), "dim")}\n\n`,
        );
        break;
      }
      case "workspace-finished": {
        const passed = event.frame.packages.every(frameSucceeded);
        const symbol = passed ? "✓" : "✗";
        const style: Style = passed ? "green" : "red";
        this.write(
          `${styled(symbol, style)} ${styled(event.frame.id, style)}  ${styled(duration(event.frame.durationMs), "dim")}\n\n`,
        );
        break;
      }
    }
  }
}
