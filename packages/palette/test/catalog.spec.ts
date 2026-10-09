import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { ExpectedError } from "@dotkit/shared/error";
import { describe, expect, it, onTestFinished } from "vitest";

import { Catalog } from "../src/catalog";
import type { Theme } from "../src/theme";

const palette = Object.fromEntries(
  Array.from({ length: 24 }, (_, index) => {
    const key = `base${index.toString(16).toUpperCase().padStart(2, "0")}`;
    const color = `#${index.toString(16).padStart(6, "0")}`;
    return [key, color];
  }),
) as Theme["palette"];

async function createFixture() {
  const directory = await mkdtemp(join(tmpdir(), "dotkit-palette-catalog-"));

  onTestFinished(async () => {
    await rm(directory, { force: true, recursive: true });
  });

  const manifest = {
    revision: "0123456789abcdef0123456789abcdef01234567",
    defaultTheme: "example-dark",
    themes: ["example-dark"],
  };
  const theme = {
    id: "example-dark",
    name: "Example Dark",
    variant: "dark",
    palette,
  } satisfies Theme;

  await writeFile(join(directory, "manifest.json"), JSON.stringify(manifest));
  await writeFile(join(directory, "example-dark.json"), JSON.stringify(theme));

  return { directory, manifest, theme };
}

describe("Catalog", () => {
  it("requires an absolute catalog directory", () => {
    expect(() => new Catalog("dist/catalog")).toThrow(ExpectedError);
  });
});

describe("catalog.list", () => {
  it("returns the validated catalog manifest", async () => {
    const { directory, manifest } = await createFixture();

    await expect(new Catalog(directory).list()).resolves.toEqual(manifest);
  });

  it("reports a missing manifest as an expected error", async () => {
    const { directory } = await createFixture();
    await rm(join(directory, "manifest.json"));

    await expect(new Catalog(directory).list()).rejects.toThrow(ExpectedError);
  });
});

describe("catalog.get", () => {
  it("returns a theme declared by the manifest", async () => {
    const { directory, theme } = await createFixture();

    await expect(new Catalog(directory).get("example-dark")).resolves.toEqual(
      theme,
    );
  });

  it("rejects a theme outside the manifest without reading its file", async () => {
    const { directory } = await createFixture();
    await writeFile(join(directory, "missing.json"), JSON.stringify({}));

    await expect(new Catalog(directory).get("missing")).rejects.toThrow(
      "Theme missing is not in the catalog manifest",
    );
  });

  it("rejects a theme whose ID does not match its filename", async () => {
    const { directory, theme } = await createFixture();
    await writeFile(
      join(directory, "example-dark.json"),
      JSON.stringify({ ...theme, id: "different" }),
    );

    await expect(new Catalog(directory).get("example-dark")).rejects.toThrow(
      "Theme ID mismatch: requested example-dark, found different",
    );
  });
});
