import { describe, expect, it, vi } from "vitest";

import { run } from "../../cli/run";
import type { CatalogManifest, Theme } from "../../src/theme";

const colors = Object.fromEntries(
  Array.from({ length: 24 }, (_, index) => [
    `base${index.toString(16).toUpperCase().padStart(2, "0")}`,
    `#${index.toString(16).padStart(6, "0")}`,
  ]),
) as Theme["palette"];
const theme = {
  id: "nord",
  name: "Nord",
  variant: "dark",
  palette: colors,
} satisfies Theme;
const manifest = {
  revision: "0123456789abcdef0123456789abcdef01234567",
  defaultTheme: "nord",
  themes: ["nord", "one-dark"],
} satisfies CatalogManifest;

function createPalette() {
  return {
    list: vi.fn(async () => manifest),
    get: vi.fn(async () => theme),
    getActiveTheme: vi.fn(async () => theme),
    setActiveTheme: vi.fn(async () => theme),
  };
}

describe("run", () => {
  it("prints theme IDs or the manifest for list", async () => {
    await expect(run(["list"], createPalette)).resolves.toBe(
      "nord\none-dark\n",
    );
    await expect(run(["list", "--json"], createPalette)).resolves.toBe(
      json(manifest),
    );
  });

  it("gets the active theme when no ID is provided", async () => {
    const palette = createPalette();

    await expect(run(["get"], () => palette)).resolves.toBe("nord\n");
    expect(palette.getActiveTheme).toHaveBeenCalledOnce();
    expect(palette.get).not.toHaveBeenCalled();
  });

  it("gets a named catalog theme and supports JSON output", async () => {
    const palette = createPalette();

    await expect(run(["get", "nord", "--json"], () => palette)).resolves.toBe(
      json(theme),
    );
    expect(palette.get).toHaveBeenCalledWith("nord");
  });

  it("sets and prints the active theme ID", async () => {
    const palette = createPalette();

    await expect(run(["set", "nord"], () => palette)).resolves.toBe("nord\n");
    expect(palette.setActiveTheme).toHaveBeenCalledWith("nord");
  });

  it("renders help without loading Palette", async () => {
    await expect(run(["--help"], failToLoadPalette)).resolves.toContain(
      "palette <command>",
    );
    await expect(run(["help", "set"], failToLoadPalette)).resolves.toContain(
      "palette set <theme-id>",
    );
  });
});

function failToLoadPalette(): never {
  throw new Error("should not load");
}

function json(value: unknown): string {
  return `${JSON.stringify(value, null, 2)}\n`;
}
