import type { CatalogManifest, Theme } from "../src/theme";
import { parseArguments } from "./arguments";
import { commandHelp, help } from "./help";

export interface PaletteApplication {
  list(): Promise<CatalogManifest>;
  get(themeId: string): Promise<Theme>;
  getActiveTheme(): Promise<Theme>;
  setActiveTheme(themeId: string): Promise<Theme>;
}

type LoadPalette = () => PaletteApplication | Promise<PaletteApplication>;

/** Executes one CLI request and returns its complete stdout payload. */
export async function run(
  arguments_: readonly string[],
  loadPalette: LoadPalette,
): Promise<string> {
  const parsed = parseArguments(arguments_);

  if (parsed.command === "help") {
    return parsed.commandName ? commandHelp(parsed.commandName) : help();
  }

  // Help remains available without loading the built catalog or state file.
  const palette = await loadPalette();

  switch (parsed.command) {
    case "list": {
      const manifest = await palette.list();
      return parsed.json ? json(manifest) : lines(manifest.themes);
    }
    case "get": {
      const theme = parsed.themeId
        ? await palette.get(parsed.themeId)
        : await palette.getActiveTheme();
      return parsed.json ? json(theme) : `${theme.id}\n`;
    }
    case "set": {
      const theme = await palette.setActiveTheme(parsed.themeId);
      return `${theme.id}\n`;
    }
  }
}

function json(value: unknown): string {
  return `${JSON.stringify(value, null, 2)}\n`;
}

function lines(values: readonly string[]): string {
  return values.length === 0 ? "" : `${values.join("\n")}\n`;
}
