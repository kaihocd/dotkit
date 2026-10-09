import { describe, expect, it } from "vitest";

import { ExpectedError } from "../src/error";

describe("ExpectedError", () => {
  it("is an Error with the concrete subclass name and cause", () => {
    const cause = new Error("underlying failure");

    class InstallError extends ExpectedError {}

    const error = new InstallError("installation failed", { cause });

    expect(error).toBeInstanceOf(Error);
    expect(error).toBeInstanceOf(ExpectedError);
    expect(error.name).toBe("InstallError");
    expect(error.message).toBe("installation failed");
    expect(error.cause).toBe(cause);
  });
});
