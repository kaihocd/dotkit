/** Shared command metadata used by help, parsing, and completion generation. */
export const cliContract = {
  name: "palette",
  description: "Inspect and activate themes from the built Palette catalog.",
  commands: {
    list: {
      description: "List available theme IDs.",
      usage: "palette list [--json]",
      argument: undefined,
      options: {
        "--json": "Write the catalog manifest as JSON.",
      },
    },
    get: {
      description: "Print the active theme or one catalog theme.",
      usage: "palette get [<theme-id>] [--json]",
      argument: {
        name: "theme-id",
        description: "Optional theme ID; omit it to get the active theme.",
      },
      options: {
        "--json": "Write the complete theme as JSON.",
      },
    },
    set: {
      description: "Set the active theme.",
      usage: "palette set <theme-id>",
      argument: {
        name: "theme-id",
        description: "Theme ID from the catalog manifest.",
      },
      options: {},
    },
  },
} as const;

export type CommandName = keyof typeof cliContract.commands;
