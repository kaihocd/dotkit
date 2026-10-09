import { describe, expect, it } from "vitest";

import { requiredEnvironment } from "../src/environment/index";

const NAME = "XDG_CONFIG_HOME";

describe("requiredEnvironment", () => {
  it("returns a present known environment variable", () => {
    expect(requiredEnvironment(NAME, { [NAME]: "/home/dev/.config" })).toBe(
      "/home/dev/.config",
    );
  });

  it("accepts an arbitrary environment variable name", () => {
    expect(
      requiredEnvironment("DOTKIT_CUSTOM", { DOTKIT_CUSTOM: "value" }),
    ).toBe("value");
  });

  it.each([undefined, ""])("rejects a missing value: %s", (value) => {
    expect(() => requiredEnvironment(NAME, { [NAME]: value })).toThrow(
      "Required environment variable is missing: XDG_CONFIG_HOME",
    );
  });
});
