import { describe, expect, it } from "vitest";

import { parseCatalogManifest, parseTheme } from "../src/theme";

const palette = {
  base00: "#000000",
  base01: "#010101",
  base02: "#020202",
  base03: "#030303",
  base04: "#040404",
  base05: "#050505",
  base06: "#060606",
  base07: "#070707",
  base08: "#080808",
  base09: "#090909",
  base0A: "#0a0a0a",
  base0B: "#0b0b0b",
  base0C: "#0c0c0c",
  base0D: "#0d0d0d",
  base0E: "#0e0e0e",
  base0F: "#0f0f0f",
  base10: "#101010",
  base11: "#111111",
  base12: "#121212",
  base13: "#131313",
  base14: "#141414",
  base15: "#151515",
  base16: "#161616",
  base17: "#171717",
};

describe("parseTheme", () => {
  const theme = {
    id: "example-dark",
    name: "Example Dark",
    author: "Dotkit",
    variant: "dark",
    palette,
  };

  it("returns a valid Base24 theme", () => {
    expect(parseTheme(theme)).toEqual(theme);
  });

  it("rejects an incomplete Base24 palette", () => {
    const { base17: _, ...incompletePalette } = palette;

    expect(() =>
      parseTheme({ ...theme, palette: incompletePalette }),
    ).toThrow();
  });

  it("rejects palette entries outside Base24", () => {
    const extraPalette = { ...palette, base18: "#181818" };

    expect(() => parseTheme({ ...theme, palette: extraPalette })).toThrow();
  });

  it("rejects colors outside the normalized hex format", () => {
    const invalidPalette = { ...palette, base00: "000000" };

    expect(() => parseTheme({ ...theme, palette: invalidPalette })).toThrow();
  });

  it("rejects an invalid theme ID", () => {
    expect(() => parseTheme({ ...theme, id: "Example Dark" })).toThrow();
  });
});

describe("parseCatalogManifest", () => {
  it("returns a valid catalog manifest", () => {
    const manifest = {
      revision: "0123456789abcdef0123456789abcdef01234567",
      defaultTheme: "example-dark",
      themes: ["example-dark", "example-light"],
    };

    expect(parseCatalogManifest(manifest)).toEqual(manifest);
  });

  it("rejects duplicate theme IDs", () => {
    expect(() =>
      parseCatalogManifest({
        revision: "0123456789abcdef0123456789abcdef01234567",
        defaultTheme: "example-dark",
        themes: ["example-dark", "example-dark"],
      }),
    ).toThrow();
  });

  it("rejects unsorted theme IDs", () => {
    expect(() =>
      parseCatalogManifest({
        revision: "0123456789abcdef0123456789abcdef01234567",
        defaultTheme: "example-dark",
        themes: ["example-light", "example-dark"],
      }),
    ).toThrow();
  });

  it("rejects a default theme outside the catalog", () => {
    expect(() =>
      parseCatalogManifest({
        revision: "0123456789abcdef0123456789abcdef01234567",
        defaultTheme: "missing",
        themes: ["example-dark"],
      }),
    ).toThrow();
  });
});
