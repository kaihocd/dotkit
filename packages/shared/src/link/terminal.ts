import { success, warn } from "../output";
import type { SymbolicLinkEvent } from "./index";

function title(value: string): string {
  return `${value[0]?.toUpperCase() ?? ""}${value.slice(1)}`;
}

/** Presents symbolic-link operation events for an interactive CLI caller. */
export function reportSymbolicLinkToTerminal(event: SymbolicLinkEvent): void {
  const message = `${event.target} -> ${event.source}`;
  if (event.phase === "preview") {
    warn(`${title(event.action)} ${message}`, { label: "PREVIEW" });
    return;
  }

  success(message, {
    label: event.action === "keep" ? "KEEP" : "LINK",
  });
}
