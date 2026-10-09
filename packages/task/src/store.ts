import { TaskError } from "./errors";
import type {
  TaskEvent,
  TaskRunId,
  TaskStateNode,
  TaskStateTree,
  TaskSubscriber,
} from "./types";

function frameSucceeded(
  event: Extract<TaskEvent, { type: "command-finished" }>,
): boolean {
  return (
    event.frame.result.status === "exited" && event.frame.result.exitCode === 0
  );
}

/** Reduces immutable runtime facts into one observable task-state tree. */
export class TaskStore {
  private readonly roots: TaskRunId[] = [];
  private readonly nodes = new Map<TaskRunId, TaskStateNode>();
  private readonly subscribers = new Set<TaskSubscriber>();

  public dispatch(event: TaskEvent): void {
    switch (event.type) {
      case "workspace-started": {
        this.assertNew(event.runId);
        this.nodes.set(event.runId, {
          runId: event.runId,
          parentRunId: event.parentRunId,
          type: "workspace",
          id: event.id,
          script: event.script,
          packageCount: event.packageCount,
          status: "running",
          children: [],
          output: [],
          startedAt: event.startedAt,
        });
        if (event.parentRunId === undefined) {
          this.roots.push(event.runId);
        } else {
          const parent = this.node(event.parentRunId);
          this.nodes.set(event.parentRunId, {
            ...parent,
            children: [...parent.children, event.runId],
          });
        }
        break;
      }
      case "command-started": {
        this.assertNew(event.runId);
        this.nodes.set(event.runId, {
          runId: event.runId,
          parentRunId: event.parentRunId,
          type: "command",
          id: event.id,
          projectName: event.projectName,
          command: event.command,
          status: "running",
          children: [],
          output: [],
          startedAt: event.startedAt,
        });
        if (event.parentRunId === undefined) {
          this.roots.push(event.runId);
        } else {
          const parent = this.node(event.parentRunId);
          this.nodes.set(event.parentRunId, {
            ...parent,
            children: [...parent.children, event.runId],
          });
        }
        break;
      }
      case "command-output": {
        const node = this.node(event.runId);
        this.nodes.set(event.runId, {
          ...node,
          output: [...node.output, event.chunk],
        });
        break;
      }
      case "command-finished": {
        const node = this.node(event.runId);
        this.nodes.set(event.runId, {
          ...node,
          status: frameSucceeded(event) ? "succeeded" : "failed",
          finishedAt: event.finishedAt,
          durationMs: event.frame.durationMs,
          result: event.frame.result,
        });
        break;
      }
      case "workspace-finished": {
        const node = this.node(event.runId);
        this.nodes.set(event.runId, {
          ...node,
          status: event.frame.packages.every(
            ({ result }) => result.status === "exited" && result.exitCode === 0,
          )
            ? "succeeded"
            : "failed",
          finishedAt: event.finishedAt,
          durationMs: event.frame.durationMs,
        });
        break;
      }
    }

    const snapshot = this.snapshot();
    for (const subscriber of this.subscribers) subscriber(snapshot, event);
  }

  public snapshot(): TaskStateTree {
    return {
      roots: [...this.roots],
      nodes: new Map(this.nodes),
    };
  }

  public subscribe(subscriber: TaskSubscriber): () => void {
    this.subscribers.add(subscriber);
    return () => this.subscribers.delete(subscriber);
  }

  private assertNew(runId: TaskRunId): void {
    if (this.nodes.has(runId)) {
      throw new TaskError(`Task run ID repeated: ${runId}`);
    }
  }

  private node(runId: TaskRunId): TaskStateNode {
    const node = this.nodes.get(runId);
    if (!node) throw new TaskError(`Unknown task run ID: ${runId}`);
    return node;
  }
}
