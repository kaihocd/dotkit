/** A package discovered from pnpm's workspace membership. */
export interface WorkspaceProject {
  readonly name: string;
  /** Absolute package directory used as a process working directory. */
  readonly directory: string;
  /** Package directory relative to the workspace root, or `.` for the root. */
  readonly relativeDirectory: string;
  /** Declared package scripts used by workspace tasks for if-present selection. */
  readonly scripts: Readonly<Record<string, string>>;
}

/**
 * Execution scope shared by Task presets and runners. The current project may
 * be the workspace root or one nested package selected from the invocation cwd.
 */
export interface ProjectContext {
  /** Absolute directory from which Task was invoked. */
  readonly cwd: string;
  /** Deepest workspace project containing `cwd`. */
  readonly project: WorkspaceProject;
  readonly workspace: {
    /** Absolute directory containing `pnpm-workspace.yaml`. */
    readonly directory: string;
    /** All projects reported by pnpm, including the workspace root. */
    readonly projects: readonly WorkspaceProject[];
  };
  /** Descendant projects owned by the current project, excluding itself. */
  readonly nestedProjects: readonly WorkspaceProject[];
}

/** An external process invocation with no shell interpretation. */
export interface CommandSpec {
  readonly executable: string;
  readonly args: readonly string[];
  /** Absolute working directory for the child process. */
  readonly cwd: string;
  /** Environment overrides merged on top of the parent environment. */
  readonly env?: Readonly<Record<string, string | undefined>>;
}

/** A Task node that owns one external process boundary. */
export interface CommandTask {
  readonly type: "command";
  readonly id: string;
  readonly command: CommandSpec;
}

/** A Task node that runs one package script across eligible child projects. */
export interface WorkspaceTask {
  readonly type: "workspace";
  readonly id: string;
  readonly script: string;
  /** Opaque arguments forwarded unchanged to every eligible package script. */
  readonly arguments: readonly string[];
}

/** Structural execution plan produced by resolving one complete Task ID. */
export type TaskNode = CommandTask | WorkspaceTask;

/** A registry entry that translates project context into an execution node. */
export interface TaskDefinition {
  readonly id: string;
  resolve(context: ProjectContext): TaskNode;
}

/** One observed output callback from a captured child-process pipe. */
export interface OutputChunk {
  /** Monotonic callback order within one command execution. */
  readonly sequence: number;
  /** Original child pipe; rendering may use a different presentation stream. */
  readonly stream: "stdout" | "stderr";
  readonly data: Uint8Array;
}

/** Terminal process outcome, including failures to create the child process. */
export type ProcessResult =
  | {
      readonly status: "exited";
      readonly exitCode: number | null;
      readonly signal: NodeJS.Signals | null;
    }
  | {
      readonly status: "spawn-error";
      readonly error: Error;
    };

/** Buffered result for one command process. */
export interface CommandFrame {
  readonly type: "command";
  readonly id: string;
  /** Project label displayed for a child workspace package. */
  readonly projectName: string;
  readonly command: CommandSpec;
  readonly output: readonly OutputChunk[];
  readonly result: ProcessResult;
  readonly durationMs: number;
}

/** Aggregate result for an all-settled workspace package execution. */
export interface WorkspaceFrame {
  readonly type: "workspace";
  readonly id: string;
  readonly script: string;
  /** Package Frames in deterministic workspace discovery order. */
  readonly packages: readonly CommandFrame[];
  readonly durationMs: number;
}

/** Buffered result for one completed top-level Task ID. */
export type TaskFrame = CommandFrame | WorkspaceFrame;

/** Stable identity for one runtime node; display IDs are not execution identity. */
export type TaskRunId = number;

export type TaskEvent =
  | {
      readonly type: "workspace-started";
      readonly runId: TaskRunId;
      readonly parentRunId?: TaskRunId;
      readonly id: string;
      readonly script: string;
      readonly packageCount: number;
      readonly startedAt: number;
    }
  | {
      readonly type: "command-started";
      readonly runId: TaskRunId;
      readonly parentRunId?: TaskRunId;
      readonly id: string;
      readonly projectName: string;
      readonly command: CommandSpec;
      readonly startedAt: number;
    }
  | {
      readonly type: "command-output";
      readonly runId: TaskRunId;
      readonly chunk: OutputChunk;
    }
  | {
      readonly type: "command-finished";
      readonly runId: TaskRunId;
      readonly frame: CommandFrame;
      readonly finishedAt: number;
    }
  | {
      readonly type: "workspace-finished";
      readonly runId: TaskRunId;
      readonly frame: WorkspaceFrame;
      readonly finishedAt: number;
    };

export type TaskRunStatus = "running" | "succeeded" | "failed";

export interface TaskStateNode {
  readonly runId: TaskRunId;
  readonly parentRunId?: TaskRunId;
  readonly type: "workspace" | "command";
  readonly id: string;
  readonly projectName?: string;
  readonly command?: CommandSpec;
  /** Workspace package script, retained structurally for rendering. */
  readonly script?: string;
  /** Number of package commands declared before concurrent execution starts. */
  readonly packageCount?: number;
  readonly status: TaskRunStatus;
  readonly children: readonly TaskRunId[];
  readonly output: readonly OutputChunk[];
  readonly startedAt: number;
  readonly finishedAt?: number;
  readonly durationMs?: number;
  readonly result?: ProcessResult;
}

export interface TaskStateTree {
  readonly roots: readonly TaskRunId[];
  readonly nodes: ReadonlyMap<TaskRunId, TaskStateNode>;
}

export type TaskSubscriber = (tree: TaskStateTree, event: TaskEvent) => void;

/** Read-only state seam consumed by renderers and other observers. */
export interface TaskStateSource {
  snapshot(): TaskStateTree;
  subscribe(subscriber: TaskSubscriber): () => void;
}
