import { execFile } from "node:child_process";
import { resolve } from "node:path";
import { promisify } from "node:util";

import { expect, it } from "vitest";

const executeFile = promisify(execFile);
const packageDirectory = resolve(import.meta.dirname, "..");

it("writes a successful non-TTY report to stdout", async () => {
  const { stdout, stderr } = await executeFile(
    "pnpm",
    [
      "exec",
      "tsx",
      resolve(packageDirectory, "cli/index.ts"),
      "exec",
      "--name=probe",
      "--",
      process.execPath,
      "-e",
      "process.stdout.write('\\u001B[90mprobe output\\u001B[39m\\n')",
    ],
    {
      cwd: packageDirectory,
      // This probe tests the standalone CLI, not the parent Task transport.
      env: {
        ...process.env,
        DOTKIT_TASK_EVENT_SOCKET: undefined,
        DOTKIT_TASK_EVENT_TOKEN: undefined,
      },
    },
  );

  expect(stdout).toContain("probe output");
  expect(stdout).toContain("✓");
  expect(stdout).not.toContain("\u001B");
  expect(stderr).toBe("");
});
