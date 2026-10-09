import { stripVTControlCharacters } from "node:util";

import { afterEach, describe, expect, it, vi } from "vitest";

import { error, success, warn, write } from "../src/output";

afterEach(() => {
  vi.restoreAllMocks();
});

describe("output", () => {
  it("writes ordinary and successful messages to stdout", () => {
    const stdout = vi
      .spyOn(process.stdout, "write")
      .mockImplementation(() => true);

    write("ordinary");
    success("installed", { label: "PROFILE" });

    expect(
      stdout.mock.calls.map(([value]) =>
        stripVTControlCharacters(String(value)),
      ),
    ).toEqual(["ordinary\n", " PROFILE  installed\n"]);
  });

  it("writes warnings and errors to stderr", () => {
    const stderr = vi
      .spyOn(process.stderr, "write")
      .mockImplementation(() => true);

    warn("already configured", { label: "SKIP" });
    error("installation failed", { label: "PROFILE_ERROR" });

    expect(
      stderr.mock.calls.map(([value]) =>
        stripVTControlCharacters(String(value)),
      ),
    ).toEqual([
      " SKIP  already configured\n",
      " PROFILE_ERROR  installation failed\n",
    ]);
  });
});
