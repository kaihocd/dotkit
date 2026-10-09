import { z } from "zod";

const paletteKeys = [
  "base00",
  "base01",
  "base02",
  "base03",
  "base04",
  "base05",
  "base06",
  "base07",
  "base08",
  "base09",
  "base0A",
  "base0B",
  "base0C",
  "base0D",
  "base0E",
  "base0F",
  "base10",
  "base11",
  "base12",
  "base13",
  "base14",
  "base15",
  "base16",
  "base17",
] as const;

const colorSchema = z.string().regex(/^#[0-9a-f]{6}$/);
const paletteSchema = z
  .object(
    Object.fromEntries(paletteKeys.map((key) => [key, colorSchema])) as {
      [Key in (typeof paletteKeys)[number]]: typeof colorSchema;
    },
  )
  .strict();

const themeIdSchema = z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/);
const themeSchema = z
  .object({
    id: themeIdSchema,
    name: z.string().min(1),
    author: z.string().optional(),
    variant: z.enum(["dark", "light"]),
    palette: paletteSchema,
  })
  .strict();
const catalogManifestSchema = z
  .object({
    revision: z.string().regex(/^[0-9a-f]{40}$/),
    defaultTheme: themeIdSchema,
    themes: z.array(themeIdSchema),
  })
  .strict()
  .superRefine(({ defaultTheme, themes }, context) => {
    const seen = new Set<string>();

    for (const [index, themeId] of themes.entries()) {
      if (seen.has(themeId)) {
        context.addIssue({
          code: "custom",
          message: `duplicate theme ID ${themeId}`,
          path: ["themes", index],
        });
      }

      if (index > 0 && themes[index - 1]! > themeId) {
        context.addIssue({
          code: "custom",
          message: "theme IDs must be sorted",
          path: ["themes", index],
        });
      }

      seen.add(themeId);
    }

    if (!seen.has(defaultTheme)) {
      context.addIssue({
        code: "custom",
        message: `default theme ${defaultTheme} is not in the catalog`,
        path: ["defaultTheme"],
      });
    }
  });

/** A complete normalized Base24 theme consumed by Palette integrations. */
export type Theme = z.infer<typeof themeSchema>;

/** The immutable index tying a catalog to one upstream Git revision. */
export type CatalogManifest = z.infer<typeof catalogManifestSchema>;

/** Validates data crossing into the Palette theme domain. */
export function parseTheme(value: unknown): Theme {
  return themeSchema.parse(value);
}

/** Validates catalog identity, ordering, uniqueness, and default membership. */
export function parseCatalogManifest(value: unknown): CatalogManifest {
  return catalogManifestSchema.parse(value);
}
