import { mkdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import { dirname, isAbsolute, normalize } from "node:path";

import { ExpectedError } from "@dotkit/shared/error";

import { hasErrorCode } from "./filesystem";

import { parseTheme, type Theme } from "./theme";

/**
 * Persists the complete active theme in one atomically replaced JSON file.
 *
 * Storing the complete theme lets consumers update without opening the catalog.
 */
export class ActiveThemeStore {
  readonly #file: string;
  readonly #temporaryFile: string;

  public constructor(file: string) {
    if (!isAbsolute(file)) {
      throw new ExpectedError(`Active theme file must be absolute: ${file}`);
    }

    this.#file = normalize(file);
    this.#temporaryFile = `${this.#file}.tmp`;
  }

  public async read(): Promise<Theme | undefined> {
    let content: string;

    try {
      content = await readFile(this.#file, "utf8");
    } catch (error) {
      if (hasErrorCode(error, "ENOENT")) {
        return undefined;
      }

      throw error;
    }

    let value: unknown;

    try {
      value = JSON.parse(content);
    } catch (error) {
      throw new ExpectedError("Invalid JSON in active theme", { cause: error });
    }

    try {
      return parseTheme(value);
    } catch (error) {
      throw new ExpectedError("Invalid active theme", { cause: error });
    }
  }

  public async write(theme: Theme): Promise<void> {
    const content = `${JSON.stringify(theme, null, 2)}\n`;

    // Avoid filesystem events when selecting the already-active theme.
    if ((await this.#readContent()) === content) {
      return;
    }

    await mkdir(dirname(this.#file), { recursive: true });

    try {
      await writeFile(this.#temporaryFile, content, {
        encoding: "utf8",
        mode: 0o644,
      });
      // rename is the publication boundary: readers see complete old or new JSON.
      await rename(this.#temporaryFile, this.#file);
    } finally {
      await rm(this.#temporaryFile, { force: true });
    }
  }

  async #readContent(): Promise<string | undefined> {
    try {
      return await readFile(this.#file, "utf8");
    } catch (error) {
      if (hasErrorCode(error, "ENOENT")) {
        return undefined;
      }

      throw error;
    }
  }
}
