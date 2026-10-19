import { isAbsolute } from "node:path";

export const XDG_NAMES = [
  "XDG_CONFIG_HOME",
  "XDG_DATA_HOME",
  "XDG_CACHE_HOME",
  "XDG_STATE_HOME",
] as const;

export type XdgName = (typeof XDG_NAMES)[number];
export type XdgEnvironment = Readonly<Record<XdgName, string>>;

export interface InstallationEnvironment {
  readonly home: string;
  readonly xdg: XdgEnvironment;
  readonly binDirectory: string;
}

export interface EnvironmentOptions {
  readonly home: string;
  readonly variables: Readonly<Record<string, string | undefined>>;
  /** Absolute defaults supplied by the platform declaration. */
  readonly defaults: XdgEnvironment;
  readonly binDirectory: string;
}

/** Resolves installation paths without reading or publishing process environment. */
export function resolveEnvironment({
  home,
  variables,
  defaults,
  binDirectory,
}: EnvironmentOptions): InstallationEnvironment {
  validate("home", home);
  validate("binDirectory", binDirectory);

  function resolveVariable(name: XdgName): string {
    validate(`${name} default`, defaults[name]);
    const value = variables[name];
    return validate(
      name,
      value === undefined || value === "" ? defaults[name] : value,
    );
  }

  const xdg: XdgEnvironment = {
    XDG_CONFIG_HOME: resolveVariable("XDG_CONFIG_HOME"),
    XDG_DATA_HOME: resolveVariable("XDG_DATA_HOME"),
    XDG_CACHE_HOME: resolveVariable("XDG_CACHE_HOME"),
    XDG_STATE_HOME: resolveVariable("XDG_STATE_HOME"),
  };

  return Object.freeze({ home, binDirectory, xdg: Object.freeze(xdg) });
}

/** Child processes inherit supplied variables, but resolved deployment paths win. */
export function createChildEnvironment(
  environment: InstallationEnvironment,
  variables: Readonly<Record<string, string | undefined>>,
): Readonly<Record<string, string>> {
  return {
    ...Object.fromEntries(
      Object.entries(variables).filter(
        (entry): entry is [string, string] => entry[1] !== undefined,
      ),
    ),
    ...environment.xdg,
    HOME: environment.home,
  };
}

function validate(name: string, value: string): string {
  if (typeof value !== "string" || value.includes("\0") || !isAbsolute(value)) {
    throw new TypeError(`${name} must be an absolute path.`);
  }
  return value;
}
