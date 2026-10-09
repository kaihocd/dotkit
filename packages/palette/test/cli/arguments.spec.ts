import { describe, expect, it } from "vitest";

import { CliUsageError, parseArguments } from "../../cli/arguments";

describe("parseArguments", () => {
  it.each([
    { arguments_: ["list"], expected: { command: "list", json: false } },
    {
      arguments_: ["list", "--json"],
      expected: { command: "list", json: true },
    },
    {
      arguments_: ["get"],
      expected: { command: "get", themeId: undefined, json: false },
    },
    {
      arguments_: ["get", "--json"],
      expected: { command: "get", themeId: undefined, json: true },
    },
    {
      arguments_: ["get", "nord"],
      expected: { command: "get", themeId: "nord", json: false },
    },
    {
      arguments_: ["get", "nord", "--json"],
      expected: { command: "get", themeId: "nord", json: true },
    },
    {
      arguments_: ["set", "nord"],
      expected: { command: "set", themeId: "nord" },
    },
  ])("parses $arguments_", ({ arguments_, expected }) => {
    expect(parseArguments(arguments_)).toEqual(expected);
  });

  it.each([
    { arguments_: ["--help"], expected: { command: "help" } },
    { arguments_: ["-h"], expected: { command: "help" } },
    { arguments_: ["help"], expected: { command: "help" } },
    {
      arguments_: ["help", "set"],
      expected: { command: "help", commandName: "set" },
    },
    {
      arguments_: ["set", "--help"],
      expected: { command: "help", commandName: "set" },
    },
  ])("parses help request $arguments_", ({ arguments_, expected }) => {
    expect(parseArguments(arguments_)).toEqual(expected);
  });

  it.each([
    { arguments_: [], message: "Missing command" },
    { arguments_: ["unknown"], message: "Unknown command: unknown" },
    {
      arguments_: ["list", "--bad"],
      message: "The list command only accepts --json",
    },
    {
      arguments_: ["get", "nord", "extra"],
      message: "The get command accepts at most one <theme-id> and --json",
    },
    {
      arguments_: ["get", "--bad"],
      message: "The get command accepts at most one <theme-id> and --json",
    },
    {
      arguments_: ["set"],
      message: "The set command requires exactly one <theme-id>",
    },
    {
      arguments_: ["set", "nord", "--json"],
      message: "The set command requires exactly one <theme-id>",
    },
    { arguments_: ["help", "unknown"], message: "Unknown command: unknown" },
    {
      arguments_: ["--help", "extra"],
      message: "Help does not accept arguments",
    },
  ])("rejects $arguments_", ({ arguments_, message }) => {
    expect(() => parseArguments(arguments_)).toThrow(
      new CliUsageError(message),
    );
  });
});
