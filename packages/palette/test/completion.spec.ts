import { describe, expect, it } from "vitest";

import { renderZshCompletion } from "../scripts/build/completion";
import type { CatalogManifest } from "../src/theme";

const manifest = {
  revision: "0123456789abcdef0123456789abcdef01234567",
  defaultTheme: "alpha",
  themes: ["alpha", "one-dark"],
} satisfies CatalogManifest;

describe("renderZshCompletion", () => {
  it("renders commands and theme IDs from the manifest", () => {
    const completion = renderZshCompletion(manifest);

    expect(completion).toContain("#compdef palette");
    expect(completion).toContain("'list:List available theme IDs.'");
    expect(completion).toContain("'set:Set the active theme.'");
    expect(completion).toContain("themes=('alpha' 'one-dark')");
    expect(completion).toContain(
      "'--json[Write the catalog manifest as JSON.]'",
    );
  });

  it("is deterministic", () => {
    expect(renderZshCompletion(manifest)).toBe(
      renderZshCompletion({ ...manifest }),
    );
  });
});
