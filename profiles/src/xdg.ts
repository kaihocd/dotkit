import { isAbsolute, relative, resolve, sep } from "node:path";

export const XDG_NAMES = [
  "XDG_CONFIG_HOME",
  "XDG_DATA_HOME",
  "XDG_CACHE_HOME",
  "XDG_STATE_HOME",
] as const;

export type XdgName = (typeof XDG_NAMES)[number];
export type XdgEnvironment = Readonly<Record<XdgName, string>>;

/** Verifies that every XDG directory is absolute and contained by home. */
export function validateXdg(
  environment: XdgEnvironment,
  home: string,
): XdgEnvironment {
  if (home.length === 0 || !isAbsolute(home)) {
    throw new TypeError("Home must be a non-empty absolute path.");
  }

  const root = resolve(home);

  for (const name of XDG_NAMES) {
    const path = environment[name];

    if (typeof path !== "string" || path.length === 0 || !isAbsolute(path)) {
      throw new TypeError(`${name} must be a non-empty absolute path.`);
    }

    const relativePath = relative(root, resolve(path));
    if (relativePath === ".." || relativePath.startsWith(`..${sep}`)) {
      throw new TypeError(
        `${name} must resolve inside the user's home directory.`,
      );
    }
  }

  return environment;
}
