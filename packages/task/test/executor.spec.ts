import { describe, expect, it } from "vitest";
import { executeCommand } from "../src/executor";

const CWD = process.cwd();

describe("executeCommand", () => {
  it("captures stdout and stderr while preserving stream identity", async () => {
    const frame = await executeCommand("fixture", "test", {
      executable: process.execPath,
      args: ["-e", "process.stdout.write('out'); process.stderr.write('err')"],
      cwd: CWD,
    });

    expect(frame.result).toMatchObject({ status: "exited", exitCode: 0 });
    expect(
      frame.output.map(({ stream, data }) => [
        stream,
        Buffer.from(data).toString(),
      ]),
    ).toEqual(
      expect.arrayContaining([
        ["stdout", "out"],
        ["stderr", "err"],
      ]),
    );
  });

  it("reports output before the process finishes", async () => {
    const observations: string[] = [];
    let finished = false;
    const execution = executeCommand(
      "fixture",
      "test",
      {
        executable: process.execPath,
        args: [
          "-e",
          "process.stdout.write('started\\n'); setTimeout(() => process.exit(0), 50)",
        ],
        cwd: CWD,
      },
      (chunk) => {
        observations.push(Buffer.from(chunk.data).toString().trim());
        observations.push(`finished:${finished}`);
      },
    ).finally(() => {
      finished = true;
    });

    await execution;
    expect(observations).toEqual(["started", "finished:false"]);
  });

  it("returns non-zero exits as frame data", async () => {
    const frame = await executeCommand("fixture", "test", {
      executable: process.execPath,
      args: ["-e", "process.exit(7)"],
      cwd: CWD,
    });

    expect(frame.result).toMatchObject({ status: "exited", exitCode: 7 });
  });
});
