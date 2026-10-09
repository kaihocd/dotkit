import { parseArgs } from "node:util";

import { ExpectedError } from "@dotkit/shared/error";
import { symbolicLink, type SymbolicLinkEvent } from "@dotkit/shared/link";
import { reportSymbolicLinkToTerminal } from "@dotkit/shared/link/terminal";
import { runScript } from "@dotkit/shared/script";

import { SLINK_CONFIG } from "./slink.config";

export interface SlinkOptions {
  /** Inspect and report every link without changing the filesystem. */
  readonly onlyPreview?: boolean;

  /** Receives structured link lifecycle events; omitted for silent use. */
  readonly observe?: (event: SymbolicLinkEvent) => void;
}

/** Installs the static Dotfiles sources under their conventional target names. */
export async function slink({
  onlyPreview = false,
  observe,
}: SlinkOptions = {}): Promise<void> {
  await symbolicLink(SLINK_CONFIG, { onlyPreview, observe });
}

/** Parses the intentionally small command-line grammar for the slink script. */
export function parseSlinkArguments(
  arguments_: readonly string[],
): Pick<SlinkOptions, "onlyPreview"> {
  try {
    const { values } = parseArgs({
      args: [...arguments_],
      options: {
        "only-preview": {
          type: "boolean",
          default: false,
        },
      },
      strict: true,
      allowPositionals: false,
    });

    return { onlyPreview: values["only-preview"] };
  } catch (cause) {
    throw new ExpectedError("Usage: pnpm slink [--only-preview]", { cause });
  }
}

if (import.meta.main) {
  await runScript(
    () =>
      slink({
        ...parseSlinkArguments(process.argv.slice(2)),
        observe: reportSymbolicLinkToTerminal,
      }),
    { label: "DOTFILES_ERROR" },
  );
}
