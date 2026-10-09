import { isAbsolute, resolve } from "node:path";

import { requiredEnvironment } from "@dotkit/shared/environment";
import { ExpectedError } from "@dotkit/shared/error";

import { ActiveThemeStore } from "./active-theme-store";
import { Catalog } from "./catalog";
import { Palette } from "./palette";

export interface CreatePaletteOptions {
  readonly catalogDirectory: string;
  /** Absolute application state directory, normally `$XDG_STATE_HOME/palette`. */
  readonly stateDirectory?: string;
}

/** Creates Palette using its on-disk catalog and active-theme snapshot. */
export function createPalette({
  catalogDirectory,
  stateDirectory = defaultStateDirectory(),
}: CreatePaletteOptions): Palette {
  if (!isAbsolute(stateDirectory)) {
    throw new ExpectedError(
      `Palette state directory must be absolute: ${stateDirectory}`,
    );
  }

  return new Palette({
    catalog: new Catalog(catalogDirectory),
    activeThemeStore: new ActiveThemeStore(
      resolve(stateDirectory, "active-theme.json"),
    ),
  });
}

/** Resolves Palette's application namespace beneath XDG state home. */
export function defaultStateDirectory(
  environment: NodeJS.ProcessEnv = process.env,
): string {
  const stateHome = requiredEnvironment("XDG_STATE_HOME", environment);
  if (!isAbsolute(stateHome)) {
    throw new ExpectedError(
      `XDG_STATE_HOME must be an absolute path: ${stateHome}`,
    );
  }

  return resolve(stateHome, "palette");
}
