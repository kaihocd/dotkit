import { join } from "node:path";

import { describe, expect, it } from "vitest";

import profiles from "../profiles.config";
import { validateXdg, type XdgEnvironment } from "../src/xdg";

const HOME = "/Users/example";

function environment(overrides: Partial<XdgEnvironment> = {}): XdgEnvironment {
  return {
    XDG_CONFIG_HOME: join(HOME, ".config"),
    XDG_DATA_HOME: join(HOME, ".local", "share"),
    XDG_CACHE_HOME: join(HOME, ".cache"),
    XDG_STATE_HOME: join(HOME, ".local", "state"),
    ...overrides,
  };
}

describe("Profiles XDG declaration", () => {
  it("resolves the standard XDG directories from home", () => {
    expect(profiles({ home: HOME }).xdg).toEqual(environment());
  });
});

describe("validateXdg", () => {
  it("accepts absolute XDG paths contained by an absolute home", () => {
    const value = environment();

    expect(validateXdg(value, HOME)).toBe(value);
  });

  it.each([
    ["", "non-empty absolute path"],
    [".config", "non-empty absolute path"],
    ["/tmp/config", "inside the user's home directory"],
    [join(HOME, "..", "other", ".config"), "inside the user's home directory"],
  ])("rejects XDG_CONFIG_HOME value %j", (path, message) => {
    expect(() =>
      validateXdg(environment({ XDG_CONFIG_HOME: path }), HOME),
    ).toThrow(message);
  });

  it("rejects a relative home directory", () => {
    expect(() => validateXdg(environment(), "Users/example")).toThrow(
      "Home must be a non-empty absolute path.",
    );
  });
});
