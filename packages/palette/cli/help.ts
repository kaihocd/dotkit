import { cliContract, type CommandName } from "./contract";

/** Renders top-level help entirely from the static CLI contract. */
export function help(): string {
  const commands = Object.values(cliContract.commands)
    .map(({ usage, description }) => `  ${usage.padEnd(32)} ${description}`)
    .join("\n");

  return `${cliContract.description}\n\nUsage:\n  ${cliContract.name} <command>\n\nCommands:\n${commands}\n\nOptions:\n  -h, --help                       Show help.\n`;
}

/** Renders help for one known command. */
export function commandHelp(commandName: CommandName): string {
  const command = cliContract.commands[commandName];
  const argument = command.argument
    ? `\nArguments:\n  ${command.argument.name.padEnd(32)} ${command.argument.description}\n`
    : "";
  const options = Object.entries(command.options);
  const renderedOptions =
    options.length > 0
      ? `\nOptions:\n${options
          .map(([name, description]) => `  ${name.padEnd(32)} ${description}`)
          .join("\n")}\n`
      : "";

  return `${command.description}\n\nUsage:\n  ${command.usage}\n${argument}${renderedOptions}`;
}
