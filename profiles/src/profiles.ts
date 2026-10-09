import type { XdgEnvironment } from "./xdg";

export interface ProfilesContext {
  readonly home: string;
}

export interface ProfilesConfig {
  readonly xdg: XdgEnvironment;
}

export type ProfilesDeclaration = (context: ProfilesContext) => ProfilesConfig;

/** Defines the user-maintained Profiles declaration with inferred values. */
export function defineProfiles(
  declaration: ProfilesDeclaration,
): ProfilesDeclaration {
  return declaration;
}
