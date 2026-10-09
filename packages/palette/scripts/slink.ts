import { homedir } from "node:os";
import { isAbsolute, join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { requiredEnvironment } from "@dotkit/shared/environment";
import { ExpectedError } from "@dotkit/shared/error";
import { symbolicLink, type SymbolicLinkEvent } from "@dotkit/shared/link";
import { reportSymbolicLinkToTerminal } from "@dotkit/shared/link/terminal";
import { runScript } from "@dotkit/shared/script";

export interface SlinkOptions {
  readonly onlyPreview?: boolean;
  readonly home?: string;
  readonly dataHome?: string;
  readonly distributionDirectory?: string;
  readonly observe?: (event: SymbolicLinkEvent) => void;
}

/** Installs Palette's built executable and Zsh completion. */
export async function slink({
  onlyPreview = false,
  home = homedir(),
  dataHome = requiredEnvironment("XDG_DATA_HOME"),
  distributionDirectory = resolve(import.meta.dirname, "..", "dist"),
  observe,
}: SlinkOptions = {}): Promise<void> {
  assertAbsolute("Home directory", home);
  assertAbsolute("XDG data directory", dataHome);
  assertAbsolute("Palette distribution directory", distributionDirectory);

  await symbolicLink(
    [
      {
        source: join(distributionDirectory, "palette.js"),
        target: join(home, ".local", "bin", "palette"),
      },
      {
        source: join(distributionDirectory, "completions", "_palette"),
        target: join(dataHome, "zsh", "site-functions", "_palette"),
      },
    ],
    { onlyPreview, observe },
  );
}

/** Parses the intentionally small command-line grammar for the slink script. */
export function parseSlinkArguments(
  arguments_: readonly string[],
): Pick<SlinkOptions, "onlyPreview"> {
  try {
    const { values } = parseArgs({
      args: [...arguments_],
      options: {
        "only-preview": { type: "boolean", default: false },
      },
      strict: true,
      allowPositionals: false,
    });

    return { onlyPreview: values["only-preview"] };
  } catch (cause) {
    throw new ExpectedError("Usage: pnpm slink [--only-preview]", { cause });
  }
}

function assertAbsolute(label: string, path: string): void {
  if (!isAbsolute(path))
    throw new ExpectedError(`${label} must be absolute: ${path}`);
}

if (import.meta.main) {
  await runScript(
    () =>
      slink({
        ...parseSlinkArguments(process.argv.slice(2)),
        observe: reportSymbolicLinkToTerminal,
      }),
    { label: "PALETTE_ERROR" },
  );
}
