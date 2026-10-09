import { mkdtemp, readFile, rm, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { ExpectedError } from "@dotkit/shared/error";
import { describe, expect, it, onTestFinished } from "vitest";

import { ActiveThemeStore } from "../src/active-theme-store";
import type { Theme } from "../src/theme";

const palette = Object.fromEntries(
  Array.from({ length: 24 }, (_, index) => {
    const key = `base${index.toString(16).toUpperCase().padStart(2, "0")}`;
    const color = `#${index.toString(16).padStart(6, "0")}`;
    return [key, color];
  }),
) as Theme["palette"];

const theme = {
  id: "example-dark",
  name: "Example Dark",
  variant: "dark",
  palette,
} satisfies Theme;

async function createFixture() {
  const directory = await mkdtemp(
    join(tmpdir(), "dotkit-palette-current-theme-"),
  );
  const file = join(directory, "nested", "theme.json");

  onTestFinished(async () => {
    await rm(directory, { force: true, recursive: true });
  });

  return { directory, file };
}

describe("ActiveThemeStore", () => {
  it("requires an absolute theme file path", () => {
    expect(() => new ActiveThemeStore("theme.json")).toThrow(ExpectedError);
  });
});

describe("activeThemeStore.read", () => {
  it("returns undefined when no active theme has been written", async () => {
    const { file } = await createFixture();

    await expect(new ActiveThemeStore(file).read()).resolves.toBeUndefined();
  });

  it("returns a valid active theme", async () => {
    const { file } = await createFixture();
    const activeThemeStore = new ActiveThemeStore(file);
    await activeThemeStore.write(theme);

    await expect(activeThemeStore.read()).resolves.toEqual(theme);
  });

  it("reports invalid JSON as an expected error", async () => {
    const { file } = await createFixture();
    const activeThemeStore = new ActiveThemeStore(file);
    await activeThemeStore.write(theme);
    await writeFile(file, "{");

    await expect(activeThemeStore.read()).rejects.toThrow(ExpectedError);
  });

  it("reports an invalid theme as an expected error", async () => {
    const { file } = await createFixture();
    const activeThemeStore = new ActiveThemeStore(file);
    await activeThemeStore.write(theme);
    await writeFile(file, JSON.stringify({ ...theme, palette: {} }));

    await expect(activeThemeStore.read()).rejects.toThrow(ExpectedError);
  });
});

describe("activeThemeStore.write", () => {
  it("creates parent directories and writes the theme atomically", async () => {
    const { directory, file } = await createFixture();

    await new ActiveThemeStore(file).write(theme);

    await expect(readFile(file, "utf8")).resolves.toBe(
      `${JSON.stringify(theme, null, 2)}\n`,
    );
    await expect(stat(join(directory, "nested"))).resolves.toBeDefined();
    await expect(readFile(`${file}.tmp`, "utf8")).rejects.toMatchObject({
      code: "ENOENT",
    });
  });

  it("does not replace the file when its content is unchanged", async () => {
    const { file } = await createFixture();
    const activeThemeStore = new ActiveThemeStore(file);
    await activeThemeStore.write(theme);
    const original = await stat(file);

    await activeThemeStore.write(theme);

    expect((await stat(file)).ino).toBe(original.ino);
  });
});
