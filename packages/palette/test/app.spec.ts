import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { ExpectedError } from "@dotkit/shared/error";
import { describe, expect, it, onTestFinished } from "vitest";

import { createPalette, defaultStateDirectory } from "../src/create-palette";
import type { CatalogManifest, Theme } from "../src/theme";

const colors = Object.fromEntries(
  Array.from({ length: 24 }, (_, index) => [
    `base${index.toString(16).toUpperCase().padStart(2, "0")}`,
    `#${index.toString(16).padStart(6, "0")}`,
  ]),
) as Theme["palette"];

describe("createPalette", () => {
  it("creates an application from explicit catalog and state directories", async () => {
    const root = await mkdtemp(join(tmpdir(), "dotkit-palette-app-"));
    const catalogDirectory = join(root, "catalog");
    const manifest = {
      revision: "0123456789abcdef0123456789abcdef01234567",
      defaultTheme: "alpha",
      themes: ["alpha"],
    } satisfies CatalogManifest;
    const theme = {
      id: "alpha",
      name: "Alpha",
      variant: "dark",
      palette: colors,
    } satisfies Theme;

    onTestFinished(async () => {
      await rm(root, { force: true, recursive: true });
    });

    await mkdir(catalogDirectory);
    await Promise.all([
      writeFile(
        join(catalogDirectory, "manifest.json"),
        JSON.stringify(manifest),
      ),
      writeFile(join(catalogDirectory, "alpha.json"), JSON.stringify(theme)),
    ]);

    const palette = createPalette({
      catalogDirectory,
      stateDirectory: join(root, "state"),
    });

    await expect(palette.list()).resolves.toEqual(manifest);
  });
});

describe("defaultStateDirectory", () => {
  it("uses XDG_STATE_HOME when it is declared", () => {
    expect(defaultStateDirectory({ XDG_STATE_HOME: "/state" })).toBe(
      "/state/palette",
    );
  });

  it("requires Profiles to provide XDG_STATE_HOME", () => {
    expect(() => defaultStateDirectory({})).toThrow(
      "Required environment variable is missing: XDG_STATE_HOME",
    );
  });

  it("rejects a relative XDG_STATE_HOME", () => {
    expect(() => defaultStateDirectory({ XDG_STATE_HOME: "state" })).toThrow(
      ExpectedError,
    );
  });
});
