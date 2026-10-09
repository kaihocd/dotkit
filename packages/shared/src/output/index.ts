import { styleText } from "node:util";

type Style = Parameters<typeof styleText>[0];
type Stream = "stdout" | "stderr";

export interface WriteOptions {
  readonly label?: string;
  readonly labelStyle?: Style;
  readonly style?: Style;
  readonly stream?: Stream;
}

export interface MessageOptions {
  readonly label?: string;
}

/** Writes a styled line to stdout or stderr. */
export function write(message: string, options: WriteOptions = {}): void {
  const {
    label,
    labelStyle = ["bgBlue", "black"],
    style,
    stream = "stdout",
  } = options;
  const output = stream === "stderr" ? process.stderr : process.stdout;
  const text = style ? styleText(style, message) : message;

  if (!label) {
    output.write(`${text}\n`);
    return;
  }

  const badge = styleText(labelStyle, ` ${label} `);
  output.write(`${badge} ${text}\n`);
}

/** Writes a successful status to stdout. */
export function success(message: string, { label }: MessageOptions = {}): void {
  write(message, {
    label,
    labelStyle: ["bgGreen", "black"],
    style: "green",
  });
}

/** Writes a warning status to stderr. */
export function warn(message: string, { label }: MessageOptions = {}): void {
  write(message, {
    label,
    labelStyle: ["bgYellow", "black"],
    style: "yellow",
    stream: "stderr",
  });
}

/** Writes an error status to stderr. */
export function error(message: string, { label }: MessageOptions = {}): void {
  write(message, {
    label,
    labelStyle: ["bgRed", "black"],
    style: "red",
    stream: "stderr",
  });
}
