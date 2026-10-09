import { ExpectedError } from "../error";

/** Environment variable name with autocomplete for names commonly used by Dotkit. */
type AnyString = string & Record<never, never>;
export type EnvironmentVariable =
  | "XDG_CONFIG_HOME"
  | "XDG_DATA_HOME"
  | "XDG_CACHE_HOME"
  | "XDG_STATE_HOME"
  | AnyString;

/** Returns a required, non-empty Dotkit environment variable. */
export function requiredEnvironment(
  name: EnvironmentVariable,
  environment: NodeJS.ProcessEnv = process.env,
): string {
  const value = environment[name];
  if (!value) {
    throw new ExpectedError(
      `Required environment variable is missing: ${name}`,
    );
  }
  return value;
}
