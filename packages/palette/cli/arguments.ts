import { ExpectedError } from "@dotkit/shared/error";

import { cliContract, type CommandName } from "./contract";

export type ParsedArguments =
  | { readonly command: "list"; readonly json: boolean }
  | {
      readonly command: "get";
      readonly themeId?: string;
      readonly json: boolean;
    }
  | { readonly command: "set"; readonly themeId: string }
  | { readonly command: "help"; readonly commandName?: CommandName };

/** An expected command-line contract violation. */
export class CliUsageError extends ExpectedError {}

/** Parses Palette arguments without loading configuration or touching the filesystem. */
export function parseArguments(arguments_: readonly string[]): ParsedArguments {
  const [command, ...values] = arguments_;

  if (!command) throw new CliUsageError("Missing command");

  if (command === "--help" || command === "-h") {
    if (values.length > 0)
      throw new CliUsageError("Help does not accept arguments");
    return { command: "help" };
  }

  if (command === "help") {
    if (values.length === 0) return { command: "help" };
    if (values.length !== 1 || !isCommandName(values[0]!)) {
      throw new CliUsageError(`Unknown command: ${values[0] ?? ""}`);
    }
    return { command: "help", commandName: values[0] };
  }

  if (!isCommandName(command))
    throw new CliUsageError(`Unknown command: ${command}`);

  if (values.length === 1 && (values[0] === "--help" || values[0] === "-h")) {
    return { command: "help", commandName: command };
  }

  switch (command) {
    case "list":
      return parseList(values);
    case "get":
      return parseGet(values);
    case "set":
      if (values.length !== 1) {
        throw new CliUsageError(
          "The set command requires exactly one <theme-id>",
        );
      }
      return { command, themeId: values[0]! };
  }
}

function parseList(values: readonly string[]): ParsedArguments {
  if (values.length > 1 || (values.length === 1 && values[0] !== "--json")) {
    throw new CliUsageError("The list command only accepts --json");
  }
  return { command: "list", json: values[0] === "--json" };
}

function parseGet(values: readonly string[]): ParsedArguments {
  const json = values.includes("--json");
  const themeIds = values.filter((value) => value !== "--json");

  if (
    values.length > 2 ||
    themeIds.length > 1 ||
    values.some(isUnknownOption)
  ) {
    throw new CliUsageError(
      "The get command accepts at most one <theme-id> and --json",
    );
  }

  return { command: "get", themeId: themeIds[0], json };
}

function isUnknownOption(value: string): boolean {
  return value.startsWith("-") && value !== "--json";
}

function isCommandName(value: string): value is CommandName {
  return Object.hasOwn(cliContract.commands, value);
}
