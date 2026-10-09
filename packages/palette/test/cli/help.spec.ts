import { describe, expect, it } from "vitest";

import { commandHelp, help } from "../../cli/help";

describe("help", () => {
  it("renders every command from the CLI contract", () => {
    const text = help();

    expect(text).toContain("Usage:\n  palette <command>");
    expect(text).toContain("palette list [--json]");
    expect(text).toContain("palette get [<theme-id>] [--json]");
    expect(text).toContain("palette set <theme-id>");
    expect(text).toContain("-h, --help");
  });
});

describe("commandHelp", () => {
  it("renders a command argument", () => {
    const text = commandHelp("set");

    expect(text).toContain("Usage:\n  palette set <theme-id>");
    expect(text).toContain("Arguments:\n  theme-id");
  });

  it("renders a command option", () => {
    const text = commandHelp("list");

    expect(text).toContain("Usage:\n  palette list [--json]");
    expect(text).toContain("Options:\n  --json");
  });
});
