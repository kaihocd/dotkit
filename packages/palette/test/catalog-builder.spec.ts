import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { ExpectedError } from "@dotkit/shared/error";
import { describe, expect, it, onTestFinished } from "vitest";

import { buildCatalog } from "../scripts/build/catalog";
import type { Base16Scheme, SourceScheme } from "../scripts/schemes/base16";
import { Catalog } from "../src/catalog";

const palette: Base16Scheme["palette"] = {
  base00: "#282c34",
  base01: "#353b45",
  base02: "#3e4451",
  base03: "#545862",
  base04: "#565c64",
  base05: "#abb2bf",
  base06: "#b6bdca",
  base07: "#c8ccd4",
  base08: "#e06c75",
  base09: "#d19a66",
  base0A: "#e5c07b",
  base0B: "#98c379",
  base0C: "#56b6c2",
  base0D: "#61afef",
  base0E: "#c678dd",
  base0F: "#be5046",
};

function source(id: string): SourceScheme {
  return {
    id,
    source: `base16/${id}.yaml`,
    scheme: {
      system: "base16",
      name: id,
      variant: "dark",
      palette: { ...palette },
    },
  };
}

async function createFixture() {
  const root = await mkdtemp(join(tmpdir(), "dotkit-palette-catalog-builder-"));
  const directory = join(root, "dist", "catalog");

  onTestFinished(async () => {
    await rm(root, { force: true, recursive: true });
  });

  return { root, directory };
}

describe("buildCatalog", () => {
  it("requires an absolute catalog directory", async () => {
    await expect(
      buildCatalog({
        directory: "dist/catalog",
        defaultTheme: "alpha",
        source: {
          revision: "0123456789abcdef0123456789abcdef01234567",
          schemes: [],
        },
      }),
    ).rejects.toThrow(ExpectedError);
  });

  it("builds a readable catalog with sorted theme IDs", async () => {
    const { directory } = await createFixture();
    const build = (input: Parameters<typeof buildCatalog>[0]["source"]) =>
      buildCatalog({ directory, defaultTheme: "alpha", source: input });
    const REVISION = "0123456789abcdef0123456789abcdef01234567";

    const manifest = await build({
      revision: REVISION,
      schemes: [source("zeta"), source("alpha")],
    });

    expect(manifest).toEqual({
      revision: REVISION,
      defaultTheme: "alpha",
      themes: ["alpha", "zeta"],
    });
    await expect(new Catalog(directory).list()).resolves.toEqual(manifest);
    await expect(new Catalog(directory).get("alpha")).resolves.toMatchObject({
      id: "alpha",
    });
  });

  it("rejects a default theme outside the source schemes before writing", async () => {
    const { directory } = await createFixture();

    await expect(
      buildCatalog({
        directory,
        defaultTheme: "missing",
        source: {
          revision: "0123456789abcdef0123456789abcdef01234567",
          schemes: [source("alpha")],
        },
      }),
    ).rejects.toThrow(ExpectedError);
    await expect(
      readFile(join(directory, "manifest.json")),
    ).rejects.toMatchObject({
      code: "ENOENT",
    });
  });

  it("preserves the existing catalog when conversion fails", async () => {
    const { directory } = await createFixture();
    const build = (input: Parameters<typeof buildCatalog>[0]["source"]) =>
      buildCatalog({ directory, defaultTheme: "alpha", source: input });
    const input = {
      revision: "0123456789abcdef0123456789abcdef01234567",
      schemes: [source("alpha")],
    };
    await build(input);
    const original = await readFile(join(directory, "manifest.json"), "utf8");
    const broken = source("broken");
    broken.scheme.palette.base00 = "#ffffff";
    broken.scheme.palette.base05 = "#ffffff";

    await expect(
      build({ ...input, schemes: [source("alpha"), broken] }),
    ).rejects.toThrow();
    await expect(
      readFile(join(directory, "manifest.json"), "utf8"),
    ).resolves.toBe(original);
  });

  it("replaces obsolete theme files from the previous catalog", async () => {
    const { directory } = await createFixture();
    const build = (input: Parameters<typeof buildCatalog>[0]["source"]) =>
      buildCatalog({ directory, defaultTheme: "alpha", source: input });
    const REVISION = "0123456789abcdef0123456789abcdef01234567";
    await build({
      revision: REVISION,
      schemes: [source("alpha"), source("obsolete")],
    });

    await build({ revision: REVISION, schemes: [source("alpha")] });

    await expect(
      readFile(join(directory, "obsolete.json")),
    ).rejects.toMatchObject({
      code: "ENOENT",
    });
  });

  it("recovers an interrupted catalog replacement before building", async () => {
    const { root, directory } = await createFixture();
    const backup = join(root, "dist", ".catalog-backup");
    await mkdir(backup, { recursive: true });
    await writeFile(join(backup, "marker"), "old catalog");

    await buildCatalog({
      directory,
      defaultTheme: "alpha",
      source: {
        revision: "0123456789abcdef0123456789abcdef01234567",
        schemes: [source("alpha")],
      },
    });

    await expect(
      readFile(join(directory, "manifest.json")),
    ).resolves.toBeDefined();
    await expect(readFile(join(backup, "marker"))).rejects.toMatchObject({
      code: "ENOENT",
    });
  });
});
