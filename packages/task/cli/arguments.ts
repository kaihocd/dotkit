import { resolve } from "node:path";
import { TaskError } from "../src/errors";
import type { CommandTask } from "../src/types";

/** Valid result of parsing Task's command-line grammar. */
export type CliInvocation =
  | {
      /** Ordered complete Task IDs parsed from the comma-separated operand. */
      readonly taskIds: readonly string[];
      /** Optional opaque command appended after all registered tasks. */
      readonly command?: CommandTask;
    }
  | {
      readonly workspace: {
        readonly script: string;
        readonly arguments: readonly string[];
      };
    }
  | { readonly help: true };

function parseTaskList(value: string): readonly string[] {
  const taskIds = value.split(",");

  if (taskIds.some((taskId) => taskId.length === 0)) {
    throw new TaskError(
      `Invalid task list "${value}": Empty task IDs are not allowed`,
    );
  }

  return taskIds;
}

/**
 * Parses Task's intentionally small CLI grammar. Everything after `--` is
 * preserved as one opaque command and is never interpreted as Task syntax.
 */
export function parseArguments(
  args: readonly string[],
  cwd = process.cwd(),
): CliInvocation {
  const helpRequested =
    (args.length === 1 && (args[0] === "--help" || args[0] === "-h")) ||
    (args.length === 2 &&
      args[0] === "exec" &&
      (args[1] === "--help" || args[1] === "-h"));
  if (args.length === 0 || helpRequested) {
    return { help: true };
  }

  const [subcommand, ...rest] = args;
  if (subcommand === "workspace") {
    const [script, ...arguments_] = rest;
    if (!script) {
      throw new TaskError("Expected a workspace script");
    }
    return { workspace: { script, arguments: arguments_ } };
  }
  if (subcommand !== "exec") {
    throw new TaskError(`Unknown command "${subcommand}"`);
  }

  const separator = rest.indexOf("--");
  const taskArguments = separator === -1 ? rest : rest.slice(0, separator);
  const commandArguments = separator === -1 ? [] : rest.slice(separator + 1);
  let name: string | undefined;
  let taskList: string | undefined;

  for (const argument of taskArguments) {
    if (argument.startsWith("--name=")) {
      name = argument.slice("--name=".length);
      if (!name) {
        throw new TaskError("--name requires a non-empty value");
      }
      continue;
    }

    if (argument.startsWith("-")) {
      throw new TaskError(`Unknown option "${argument}"`);
    }

    if (taskList) {
      throw new TaskError('Expected one comma-separated task list before "--"');
    }

    taskList = argument;
  }

  if (separator !== -1 && commandArguments.length === 0) {
    throw new TaskError('Expected an executable after "--"');
  }

  if (name && commandArguments.length === 0) {
    throw new TaskError("--name can only be used with an appended command");
  }

  if (!taskList && commandArguments.length === 0) {
    throw new TaskError('Expected a task list or a command after "--"');
  }

  let command: CommandTask | undefined;
  if (commandArguments.length > 0) {
    const [executable, ...commandArgs] = commandArguments;
    if (!executable) {
      throw new TaskError('Expected an executable after "--"');
    }

    command = {
      type: "command",
      id: name ?? commandArguments.join(" "),
      command: {
        executable,
        args: commandArgs,
        cwd: resolve(cwd),
      },
    };
  }

  return {
    taskIds: taskList ? parseTaskList(taskList) : [],
    command,
  };
}
