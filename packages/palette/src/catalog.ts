import { readFile } from "node:fs/promises";
import { isAbsolute, join, normalize } from "node:path";

import { ExpectedError } from "@dotkit/shared/error";

import { hasErrorCode } from "./filesystem";

import {
  parseCatalogManifest,
  parseTheme,
  type CatalogManifest,
  type Theme,
} from "./theme";

/** A read-only view of one validated, on-disk Palette catalog. */
export class Catalog {
  readonly #directory: string;

  public constructor(directory: string) {
    if (!isAbsolute(directory)) {
      throw new ExpectedError(
        `Catalog directory must be absolute: ${directory}`,
      );
    }

    this.#directory = normalize(directory);
  }

  public async list(): Promise<CatalogManifest> {
    const value = await readJson(
      join(this.#directory, "manifest.json"),
      "catalog manifest",
    );

    try {
      return parseCatalogManifest(value);
    } catch (error) {
      throw new ExpectedError("Invalid catalog manifest", { cause: error });
    }
  }

  public async get(themeId: string): Promise<Theme> {
    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(themeId)) {
      throw new ExpectedError(`Invalid theme ID: ${themeId}`);
    }

    // The manifest is authoritative; an unlisted JSON file is not a public theme.
    const manifest = await this.list();
    if (!manifest.themes.includes(themeId)) {
      throw new ExpectedError(
        `Theme ${themeId} is not in the catalog manifest`,
      );
    }

    const value = await readJson(
      join(this.#directory, `${themeId}.json`),
      `theme ${themeId}`,
    );
    let theme: Theme;

    try {
      theme = parseTheme(value);
    } catch (error) {
      throw new ExpectedError(`Invalid theme ${themeId}`, { cause: error });
    }

    // Prevent a renamed or misplaced file from impersonating another theme.
    if (theme.id !== themeId) {
      throw new ExpectedError(
        `Theme ID mismatch: requested ${themeId}, found ${theme.id}`,
      );
    }

    return theme;
  }
}

async function readJson(path: string, label: string): Promise<unknown> {
  let content: string;

  try {
    content = await readFile(path, "utf8");
  } catch (error) {
    if (hasErrorCode(error, "ENOENT")) {
      throw new ExpectedError(`Missing ${label}`, { cause: error });
    }

    throw error;
  }

  try {
    return JSON.parse(content);
  } catch (error) {
    throw new ExpectedError(`Invalid JSON in ${label}`, { cause: error });
  }
}
