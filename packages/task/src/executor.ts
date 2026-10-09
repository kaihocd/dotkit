import { spawn } from "node:child_process";
import type {
  CommandFrame,
  CommandSpec,
  OutputChunk,
  ProcessResult,
} from "./types";

/**
 * Runs one process without a shell and buffers observed stdout/stderr chunks.
 * Chunk sequence preserves callback observation order; it does not claim
 * kernel-level ordering across the two separate pipes.
 */
export async function executeCommand(
  id: string,
  projectName: string,
  command: CommandSpec,
  observeOutput: (chunk: OutputChunk) => void = () => undefined,
): Promise<CommandFrame> {
  const startedAt = performance.now();
  const output: OutputChunk[] = [];
  let sequence = 0;

  const result = await new Promise<ProcessResult>((done) => {
    let spawnError: Error | undefined;
    const child = spawn(command.executable, command.args, {
      cwd: command.cwd,
      env: {
        ...process.env,
        FORCE_COLOR: process.env.FORCE_COLOR ?? "1",
        ...command.env,
      },
      shell: false,
      stdio: ["inherit", "pipe", "pipe"],
    });

    child.stdout.on("data", (data: Uint8Array) => {
      const chunk: OutputChunk = {
        sequence: sequence++,
        stream: "stdout",
        data,
      };
      output.push(chunk);
      observeOutput(chunk);
    });
    child.stderr.on("data", (data: Uint8Array) => {
      const chunk: OutputChunk = {
        sequence: sequence++,
        stream: "stderr",
        data,
      };
      output.push(chunk);
      observeOutput(chunk);
    });
    child.once("error", (error) => {
      spawnError = error;
    });
    child.once("close", (exitCode, signal) => {
      if (spawnError) {
        done({ status: "spawn-error", error: spawnError });
        return;
      }
      done({ status: "exited", exitCode, signal });
    });
  });

  return {
    type: "command",
    id,
    projectName,
    command,
    output,
    result,
    durationMs: performance.now() - startedAt,
  };
}

/** Reports success only for a normal zero-code process exit. */
export function commandSucceeded(frame: CommandFrame): boolean {
  return frame.result.status === "exited" && frame.result.exitCode === 0;
}
