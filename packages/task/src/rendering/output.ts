import { stripVTControlCharacters, styleText } from "node:util";
import type { CommandFrame, OutputChunk, TaskStateNode } from "../types";

export type Style = Parameters<typeof styleText>[0];

export function styled(value: string, style: Style): string {
  return styleText(style, value, { stream: process.stderr });
}

export function duration(durationMs: number): string {
  return durationMs < 1000
    ? `${Math.round(durationMs)}ms`
    : `${(durationMs / 1000).toFixed(1)}s`;
}

/** Decodes captured chunks into stable logical lines without losing split UTF-8. */
export function outputLines(output: readonly OutputChunk[]): readonly string[] {
  const decoder = new TextDecoder();
  let text = "";
  for (const chunk of output.toSorted(
    (left, right) => left.sequence - right.sequence,
  )) {
    text += decoder.decode(chunk.data, { stream: true });
  }
  text += decoder.decode();
  const lines = text
    .replaceAll("\r\n", "\n")
    .replaceAll("\r", "\n")
    .split("\n");
  if (lines.at(-1) === "") lines.pop();
  return lines;
}

export function frameSucceeded(frame: CommandFrame): boolean {
  return frame.result.status === "exited" && frame.result.exitCode === 0;
}

export function trimmedOutputLines(
  output: readonly OutputChunk[],
): readonly string[] {
  const lines = [...outputLines(output)];
  while (lines[0]?.trim() === "") lines.shift();
  while (lines.at(-1)?.trim() === "") lines.pop();
  return lines;
}

export function sentenceCase(value: string): string {
  return value.length === 0
    ? value
    : `${value[0]!.toUpperCase()}${value.slice(1)}`;
}

export function resultLabel(node: TaskStateNode): string {
  if (!node.result) return "failed";
  if (node.result.status === "spawn-error") {
    return `failed to start: ${node.result.error.message}`;
  }
  if (node.result.signal) return `terminated by ${node.result.signal}`;
  return `exited with code ${node.result.exitCode ?? "unknown"}`;
}

export function persistentOutput(node: TaskStateNode): readonly string[] {
  return trimmedOutputLines(node.output);
}

export function truncateLiveLine(
  value: string,
  availableColumns: number,
): string {
  const plain = stripVTControlCharacters(value);
  const characters = [...plain];
  if (characters.length <= availableColumns) return plain;
  if (availableColumns <= 1) return "…";
  return `${characters.slice(0, availableColumns - 1).join("")}…`;
}

const ESCAPE = "\u001B";
const BELL = "\u0007";
const SGR_SEQUENCE_PATTERN = new RegExp(`^${ESCAPE}\\[[0-9;]*m$`, "u");
const CONTROL_SEQUENCE_PATTERN = new RegExp(
  `${ESCAPE}\\][^${BELL}${ESCAPE}]*(?:${BELL}|${ESCAPE}\\\\)|${ESCAPE}\\[[0-?]*[ -/]*[@-~]|${ESCAPE}[@-_]`,
  "gu",
);
const SGR_RESET = `${ESCAPE}[0m`;
const LINK_CLOSE = `${ESCAPE}]8;;${BELL}`;
const LINK_PATTERN = new RegExp(
  `^${ESCAPE}\\]8;[^;]*;([^${BELL}${ESCAPE}]*)(?:${BELL}|${ESCAPE}\\\\)$`,
  "u",
);

/** Preserves only SGR text styling while removing terminal-control sequences. */
function safeStyledTokens(value: string): readonly string[] {
  const tokens: string[] = [];
  let offset = 0;
  for (const match of value.matchAll(CONTROL_SEQUENCE_PATTERN)) {
    tokens.push(value.slice(offset, match.index));
    const sequence = match[0];
    if (SGR_SEQUENCE_PATTERN.test(sequence) || LINK_PATTERN.test(sequence))
      tokens.push(sequence);
    offset = match.index + sequence.length;
  }
  tokens.push(value.slice(offset));
  return tokens;
}

export function truncateStyledLine(
  value: string,
  availableColumns: number,
): string {
  if (availableColumns <= 1) return "…";
  const tokens = safeStyledTokens(value);
  let visibleLength = 0;
  let result = "";
  let hasStyle = false;
  let activeLink = "";
  const plainLength = [...stripVTControlCharacters(tokens.join(""))].length;
  const truncated = plainLength > availableColumns;
  const limit = truncated ? availableColumns - 1 : plainLength;
  for (const token of tokens) {
    const link = token.match(LINK_PATTERN);
    if (link) {
      result += token;
      activeLink = link[1] ? token : "";
      continue;
    }
    if (SGR_SEQUENCE_PATTERN.test(token)) {
      result += token;
      hasStyle = true;
      continue;
    }
    for (const character of token) {
      if (visibleLength >= limit) break;
      result += character;
      visibleLength += 1;
    }
    if (visibleLength >= limit) break;
  }
  if (activeLink) result += LINK_CLOSE;
  if (truncated) result += "…";
  return hasStyle ? `${result}${SGR_RESET}` : result;
}

export function wrapStyledLine(
  value: string,
  firstPrefix: string,
  continuationPrefix: string,
  columns: number,
): readonly string[] {
  const tokens = safeStyledTokens(value);
  const lines: string[] = [];
  let prefix = firstPrefix;
  let line = prefix;
  let visibleLength = 0;
  let activeStyles = "";
  let activeLink = "";
  let hasStyle = false;

  const commitLine = (): void => {
    lines.push(
      `${line}${activeLink ? LINK_CLOSE : ""}${hasStyle ? SGR_RESET : ""}`,
    );
    prefix = continuationPrefix;
    line = `${prefix}${activeStyles}${activeLink}`;
    visibleLength = 0;
  };

  for (const token of tokens) {
    const link = token.match(LINK_PATTERN);
    if (link) {
      line += token;
      activeLink = link[1] ? token : "";
      continue;
    }
    if (SGR_SEQUENCE_PATTERN.test(token)) {
      line += token;
      hasStyle = true;
      const parameters = token.slice(2, -1).split(";");
      activeStyles =
        parameters.includes("0") || parameters[0] === ""
          ? ""
          : `${activeStyles}${token}`;
      continue;
    }
    for (const character of token) {
      const available = Math.max(1, columns - [...prefix].length - 1);
      if (visibleLength >= available) commitLine();
      line += character;
      visibleLength += 1;
    }
  }
  if (visibleLength > 0 || lines.length === 0) commitLine();
  return lines;
}

export function wrapPersistentLine(
  value: string,
  firstPrefix: string,
  continuationPrefix: string,
  columns: number,
): readonly string[] {
  const characters = [...stripVTControlCharacters(value)];
  const lines: string[] = [];
  let prefix = firstPrefix;
  do {
    const available = Math.max(1, columns - [...prefix].length - 1);
    lines.push(`${prefix}${characters.splice(0, available).join("")}`);
    prefix = continuationPrefix;
  } while (characters.length > 0);
  return lines;
}
