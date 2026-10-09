import type { CatalogManifest, Theme } from "./theme";

/** Read-only theme catalog required by Palette use cases. */
export interface PaletteCatalog {
  list(): Promise<CatalogManifest>;
  get(themeId: string): Promise<Theme>;
}

/** Persistence boundary for the complete active theme snapshot. */
export interface ActiveThemeStorage {
  read(): Promise<Theme | undefined>;
  write(theme: Theme): Promise<void>;
}

export interface PaletteDependencies {
  readonly catalog: PaletteCatalog;
  readonly activeThemeStore: ActiveThemeStorage;
}

/** Theme catalog queries and active-theme state transitions. */
export class Palette {
  readonly #catalog: PaletteCatalog;
  readonly #activeThemeStore: ActiveThemeStorage;

  public constructor({ catalog, activeThemeStore }: PaletteDependencies) {
    this.#catalog = catalog;
    this.#activeThemeStore = activeThemeStore;
  }

  public list(): Promise<CatalogManifest> {
    return this.#catalog.list();
  }

  public get(themeId: string): Promise<Theme> {
    return this.#catalog.get(themeId);
  }

  /** Returns the active theme, activating the catalog default on first use. */
  public async getActiveTheme(): Promise<Theme> {
    const activeTheme = await this.#activeThemeStore.read();
    if (activeTheme) return activeTheme;

    const manifest = await this.#catalog.list();
    const defaultTheme = await this.#catalog.get(manifest.defaultTheme);
    await this.#activeThemeStore.write(defaultTheme);
    return defaultTheme;
  }

  /** Validates and publishes a catalog theme as the active theme. */
  public async setActiveTheme(themeId: string): Promise<Theme> {
    const theme = await this.#catalog.get(themeId);
    await this.#activeThemeStore.write(theme);
    return theme;
  }
}
