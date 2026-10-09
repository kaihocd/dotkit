import type { Terminal } from "./core";

class ProcessTerminal implements Terminal {
  public constructor(private readonly stream: NodeJS.WriteStream) {}

  public get columns(): number {
    const columns = this.stream.columns;
    return columns && columns > 0 ? columns : 80;
  }

  public get rows(): number {
    const rows = this.stream.rows;
    return rows && rows > 0 ? rows : 24;
  }

  public write(data: string): void {
    this.stream.write(data);
  }

  public clearLines(count: number): void {
    for (let index = 0; index < count; index += 1) {
      this.stream.write("\u001B[1A\r\u001B[2K");
    }
  }

  public hideCursor(): void {
    this.stream.write("\u001B[?25l");
  }

  public showCursor(): void {
    this.stream.write("\u001B[?25h");
  }
}

/** Standard output adapter for stable non-interactive reports. */
export class StdoutTerminal extends ProcessTerminal {
  public constructor() {
    super(process.stdout);
  }
}

/** Standard error adapter for the interactive terminal UI. */
export class StderrTerminal extends ProcessTerminal {
  public constructor() {
    super(process.stderr);
  }
}
