import { resolve } from "node:path";

/** Absolute root of the Palette workspace package. */
export const PACKAGE_DIRECTORY = resolve(import.meta.dirname);

/** Package-owned staging directory used before atomically publishing a build. */
export const BUILD_DIRECTORY = resolve(PACKAGE_DIRECTORY, ".build");

/** Package-owned directory containing artifacts ready for synchronization. */
export const DIST_DIRECTORY = resolve(PACKAGE_DIRECTORY, "dist");

/** Local Base16 input, prepared by ensure and consumed by offline builds. */
export const SCHEME_DIRECTORY = resolve(PACKAGE_DIRECTORY, "schemes/base16");

/** Immutable upstream commit fetched when the local scheme collection is absent. */
export const SCHEME_REVISION = "fdca32a0d14ec80ad83a78a9ccb85592ca6cb9e1";

/** Theme selected when Palette has no persisted active theme. */
export const DEFAULT_THEME = "default-dark";
