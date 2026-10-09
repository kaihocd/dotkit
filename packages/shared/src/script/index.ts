import { ExpectedError } from "../error";
import { error as writeError } from "../output";

export interface RunScriptOptions {
  readonly label?: string;
}

/** Runs a TypeScript script and presents expected failures without hiding defects. */
export async function runScript(
  operation: () => void | Promise<void>,
  { label }: RunScriptOptions = {},
): Promise<void> {
  try {
    await operation();
  } catch (error) {
    if (!(error instanceof ExpectedError)) {
      throw error;
    }

    writeError(error.message, { label });
    process.exitCode = 1;
  }
}
