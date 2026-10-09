import { describe, expect, it } from "vitest";

import {
  convertToBase24,
  contrastRatio,
  lightness,
} from "../scripts/build/base24";
import type { Base16Scheme, SourceScheme } from "../scripts/schemes/base16";
import type { Theme } from "../src/theme";

const palette: Base16Scheme["palette"] = {
  base00: "#282c34",
  base01: "#353b45",
  base02: "#3e4451",
  base03: "#545862",
  base04: "#565c64",
  base05: "#abb2bf",
  base06: "#b6bdca",
  base07: "#c8ccd4",
  base08: "#E06C75",
  base09: "#d19a66",
  base0A: "#e5c07b",
  base0B: "#98c379",
  base0C: "#56b6c2",
  base0D: "#61afef",
  base0E: "#c678dd",
  base0F: "#be5046",
};

function source(overrides: Partial<Base16Scheme> = {}): SourceScheme {
  return {
    id: "one-dark",
    source: "base16/one-dark.yaml",
    scheme: {
      system: "base16",
      name: "One Dark",
      author: "Dotkit",
      variant: "dark",
      palette,
      ...overrides,
    },
  };
}

describe("convertToBase24", () => {
  it("returns a normalized Base24 theme", () => {
    const theme = convertToBase24(source());

    expect(theme).toMatchObject({
      id: "one-dark",
      name: "One Dark",
      author: "Dotkit",
      variant: "dark",
      palette: {
        base08: "#e06c75",
        base09: "#d19a66",
        base0F: "#be5046",
      },
    });
    expect(Object.keys(theme.palette)).toHaveLength(24);
    expect(
      Object.values(theme.palette).every((color) =>
        /^#[0-9a-f]{6}$/.test(color),
      ),
    ).toBe(true);
    expect(
      contrastRatio(theme.palette.base00, theme.palette.base05),
    ).toBeGreaterThanOrEqual(6.5);
  });

  it("creates ordered neutral levels for dark and light themes", () => {
    const dark = convertToBase24(source()).palette;
    const light = convertToBase24(
      source({
        variant: "light",
        palette: { ...palette, base00: "#ffffff", base05: "#111111" },
      }),
    ).palette;

    expectNeutralOrder(dark, "dark");
    expectNeutralOrder(light, "light");
  });

  it("reserves two extended background levels away from base00", () => {
    const dark = convertToBase24(
      source({ palette: { ...palette, base00: "#000000" } }),
    ).palette;
    const light = convertToBase24(
      source({
        variant: "light",
        palette: { ...palette, base00: "#ffffff", base05: "#111111" },
      }),
    ).palette;

    expect(lightness(dark.base11)).toBeLessThan(lightness(dark.base10));
    expect(lightness(dark.base10)).toBeLessThan(lightness(dark.base00));
    expect(lightness(light.base00)).toBeLessThan(lightness(light.base10));
    expect(lightness(light.base10)).toBeLessThan(lightness(light.base11));
  });

  it("derives bright red from base08 rather than base09", () => {
    const baseline = convertToBase24(source()).palette;
    const changedRed = convertToBase24(
      source({ palette: { ...palette, base08: "#00ff00" } }),
    ).palette;
    const changedOrange = convertToBase24(
      source({ palette: { ...palette, base09: "#00ff00" } }),
    ).palette;

    expect(changedRed.base12).not.toBe(baseline.base12);
    expect(changedOrange.base12).toBe(baseline.base12);
  });

  it("omits an empty author", () => {
    expect(convertToBase24(source({ author: "" }))).not.toHaveProperty(
      "author",
    );
  });

  it("reports the source when conversion fails", () => {
    expect(() =>
      convertToBase24(
        source({
          palette: { ...palette, base00: "#ffffff", base05: "#ffffff" },
        }),
      ),
    ).toThrow(
      "Failed to convert base16/one-dark.yaml: Unable to reach 6.5:1 foreground contrast",
    );
  });
});

function expectNeutralOrder(
  colors: Theme["palette"],
  variant: Theme["variant"],
): void {
  const values = [
    "base00",
    "base01",
    "base02",
    "base03",
    "base04",
    "base05",
  ].map((key) => lightness(colors[key as keyof Theme["palette"]]));

  for (let index = 1; index < values.length; index += 1) {
    if (variant === "dark") {
      expect(values[index]).toBeGreaterThan(values[index - 1]!);
    } else {
      expect(values[index]).toBeLessThan(values[index - 1]!);
    }
  }
}
