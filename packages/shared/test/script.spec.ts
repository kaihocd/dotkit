import { afterEach, describe, expect, it, vi } from "vitest";

import { ExpectedError } from "../src/error";
import { runScript } from "../src/script";

const originalExitCode = process.exitCode;

afterEach(() => {
  process.exitCode = originalExitCode;
  vi.restoreAllMocks();
});

describe("runScript", () => {
  it("runs synchronous and asynchronous operations", async () => {
    const operations: string[] = [];

    await runScript(() => {
      operations.push("sync");
    });
    await runScript(async () => {
      await Promise.resolve();
      operations.push("async");
    });

    expect(operations).toEqual(["sync", "async"]);
    expect(process.exitCode).toBe(originalExitCode);
  });

  it("writes an expected failure to stderr and sets a failing exit status", async () => {
    const write = vi
      .spyOn(process.stderr, "write")
      .mockImplementation(() => true);

    class InstallError extends ExpectedError {}

    await runScript(
      () => {
        throw new InstallError("expected failure");
      },
      { label: "INSTALL_ERROR" },
    );

    expect(write).toHaveBeenCalledOnce();
    expect(String(write.mock.calls[0]?.[0])).toContain("INSTALL_ERROR");
    expect(String(write.mock.calls[0]?.[0])).toContain("expected failure");
    expect(process.exitCode).toBe(1);
  });

  it("preserves unexpected errors and their stacks", async () => {
    const error = new Error("unexpected failure");

    await expect(
      runScript(() => {
        throw error;
      }),
    ).rejects.toBe(error);
  });
});
