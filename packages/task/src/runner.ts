import type { ProjectContext, WorkspaceProject } from "./types";
import { TaskFailedError } from "./errors";
import { commandSucceeded, executeCommand } from "./executor";
import { TaskStore } from "./store";
import type {
  CommandFrame,
  CommandSpec,
  OutputChunk,
  TaskFrame,
  TaskNode,
  TaskRunId,
  WorkspaceFrame,
  WorkspaceTask,
} from "./types";

type ExecuteCommand = (
  id: string,
  projectName: string,
  command: CommandSpec,
  observeOutput?: (chunk: OutputChunk) => void,
) => Promise<CommandFrame>;

type NestedEnvironment = (
  parentRunId: TaskRunId,
) => Readonly<Record<string, string>>;

function frameSucceeded(frame: TaskFrame): boolean {
  return frame.type === "command"
    ? commandSucceeded(frame)
    : frame.packages.every(commandSucceeded);
}

/** Executes tasks while publishing their live lifecycle into a TaskStore. */
export class TaskRunner {
  private nextRunId = 1;

  public constructor(
    private readonly store: TaskStore,
    private readonly execute: ExecuteCommand = executeCommand,
    private readonly nestedEnvironment?: NestedEnvironment,
  ) {}

  public async run(
    tasks: readonly TaskNode[],
    context: ProjectContext,
  ): Promise<void> {
    for (const task of tasks) {
      // Top-level tasks intentionally execute in declaration order and fail fast.
      // oxlint-disable-next-line no-await-in-loop
      const frame = await this.runTask(task, context);
      if (!frameSucceeded(frame)) {
        throw new TaskFailedError(`Task "${task.id}" failed`);
      }
    }
  }

  private async runTask(
    task: TaskNode,
    context: ProjectContext,
  ): Promise<TaskFrame> {
    return task.type === "command"
      ? this.runCommand(
          this.allocateRunId(),
          undefined,
          task.id,
          context.project.name,
          task.command,
        )
      : this.runWorkspaceTask(task, context);
  }

  private async runWorkspaceTask(
    task: WorkspaceTask,
    context: ProjectContext,
  ): Promise<WorkspaceFrame> {
    const runId = this.allocateRunId();
    const startedAt = performance.now();
    const packages = context.nestedProjects.filter(
      (project) => project.scripts[task.script] !== undefined,
    );
    this.store.dispatch({
      type: "workspace-started",
      runId,
      id: task.id,
      script: task.script,
      packageCount: packages.length,
      startedAt,
    });
    const childRuns = packages.map((project) => ({
      project,
      runId: this.allocateRunId(),
    }));
    const frames = await Promise.all(
      childRuns.map(({ project, runId: childRunId }) =>
        this.runPackageScript(project, task, runId, childRunId),
      ),
    );
    const frame: WorkspaceFrame = {
      type: "workspace",
      id: task.id,
      script: task.script,
      packages: frames,
      durationMs: performance.now() - startedAt,
    };
    this.store.dispatch({
      type: "workspace-finished",
      runId,
      frame,
      finishedAt: performance.now(),
    });
    return frame;
  }

  private runPackageScript(
    project: WorkspaceProject,
    task: WorkspaceTask,
    parentRunId: TaskRunId,
    runId: TaskRunId,
  ): Promise<CommandFrame> {
    return this.runCommand(
      runId,
      parentRunId,
      `${project.name} ${task.script}`,
      project.name,
      {
        executable: "pnpm",
        args: ["run", task.script, ...task.arguments],
        cwd: project.directory,
        env: this.nestedEnvironment?.(runId),
      },
    );
  }

  private async runCommand(
    runId: TaskRunId,
    parentRunId: TaskRunId | undefined,
    id: string,
    projectName: string,
    command: CommandSpec,
  ): Promise<CommandFrame> {
    this.store.dispatch({
      type: "command-started",
      runId,
      parentRunId,
      id,
      projectName,
      command,
      startedAt: performance.now(),
    });
    const frame = await this.execute(id, projectName, command, (chunk) => {
      this.store.dispatch({ type: "command-output", runId, chunk });
    });
    this.store.dispatch({
      type: "command-finished",
      runId,
      frame,
      finishedAt: performance.now(),
    });
    return frame;
  }

  private allocateRunId(): TaskRunId {
    return this.nextRunId++;
  }
}
