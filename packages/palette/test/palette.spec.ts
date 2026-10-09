import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { describe, expect, it, onTestFinished } from "vitest";

import { Palette } from "../src/palette";
import { Catalog } from "../src/catalog";
import { ActiveThemeStore } from "../src/active-theme-store";
import type { CatalogManifest, Theme } from "../src/theme";

const colors = Object.fromEntries(
  Array.from({ length: 24 }, (_, index) => [
    `base${index.toString(16).toUpperCase().padStart(2, "0")}`,
    `#${index.toString(16).padStart(6, "0")}`,
  ]),
) as Theme["palette"];

function theme(id: string): Theme {
  return {
    id,
    name: id,
    variant: "dark",
    palette: { ...colors },
  };
}

async function createFixture() {
  const root = await mkdtemp(join(tmpdir(), "dotkit-palette-application-"));
  const catalogDirectory = join(root, "catalog");
  const activeThemeStoreFile = join(root, "state", "theme.json");
  const manifest = {
    revision: "0123456789abcdef0123456789abcdef01234567",
    defaultTheme: "alpha",
    themes: ["alpha", "zeta"],
  } satisfies CatalogManifest;

  onTestFinished(async () => {
    await rm(root, { force: true, recursive: true });
  });

  await mkdir(catalogDirectory);
  await Promise.all([
    writeFile(
      join(catalogDirectory, "manifest.json"),
      JSON.stringify(manifest),
    ),
    writeFile(
      join(catalogDirectory, "alpha.json"),
      JSON.stringify(theme("alpha")),
    ),
    writeFile(
      join(catalogDirectory, "zeta.json"),
      JSON.stringify(theme("zeta")),
    ),
  ]);

  const activeThemeStore = new ActiveThemeStore(activeThemeStoreFile);
  const catalog = new Catalog(catalogDirectory);
  const palette = new Palette({ catalog, activeThemeStore });

  return { palette, activeThemeStore, manifest };
}

describe("palette.list", () => {
  it("returns the catalog manifest", async () => {
    const { palette, manifest } = await createFixture();

    await expect(palette.list()).resolves.toEqual(manifest);
  });
});

describe("palette.get", () => {
  it("returns a theme from the catalog", async () => {
    const { palette } = await createFixture();

    await expect(palette.get("zeta")).resolves.toEqual(theme("zeta"));
  });
});

describe("palette.getActiveTheme", () => {
  it("returns the persisted active theme", async () => {
    const { palette, activeThemeStore } = await createFixture();
    await activeThemeStore.write(theme("zeta"));

    await expect(palette.getActiveTheme()).resolves.toEqual(theme("zeta"));
  });

  it("persists and returns the catalog default when no theme is active", async () => {
    const { palette, activeThemeStore } = await createFixture();

    await expect(palette.getActiveTheme()).resolves.toEqual(theme("alpha"));
    await expect(activeThemeStore.read()).resolves.toEqual(theme("alpha"));
  });
});

describe("palette.setActiveTheme", () => {
  it("persists and returns a selected catalog theme", async () => {
    const { palette, activeThemeStore } = await createFixture();

    await expect(palette.setActiveTheme("zeta")).resolves.toEqual(
      theme("zeta"),
    );
    await expect(activeThemeStore.read()).resolves.toEqual(theme("zeta"));
  });

  it("rejects a theme outside the catalog without changing the active theme", async () => {
    const { palette, activeThemeStore } = await createFixture();
    await activeThemeStore.write(theme("alpha"));

    await expect(palette.setActiveTheme("missing")).rejects.toThrow(
      "Theme missing is not in the catalog manifest",
    );
    await expect(activeThemeStore.read()).resolves.toEqual(theme("alpha"));
  });
});
