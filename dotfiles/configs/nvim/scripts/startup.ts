import { execFileSync } from "node:child_process";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { performance } from "node:perf_hooks";
import { parseArgs } from "node:util";

interface StartupEntry {
  readonly description: string;
  readonly selfMilliseconds: number;
  readonly totalMilliseconds: number;
}

interface StartupOptions {
  readonly iterations: number;
  readonly top: number;
}

function positiveInteger(value: string, option: string): number {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 1) {
    throw new Error(`${option} must be a positive integer`);
  }

  return parsed;
}

/** Parses the startup report's intentionally small command-line interface. */
export function parseStartupArguments(
  arguments_: readonly string[],
): StartupOptions {
  try {
    const { values } = parseArgs({
      args: [...arguments_],
      options: {
        iterations: { type: "string", default: "50" },
        top: { type: "string", default: "20" },
      },
      strict: true,
      allowPositionals: false,
    });

    return {
      iterations: positiveInteger(values.iterations, "--iterations"),
      top: positiveInteger(values.top, "--top"),
    };
  } catch (cause) {
    if (
      cause instanceof Error &&
      cause.message.includes("must be a positive integer")
    ) {
      throw cause;
    }
    throw new Error(
      "Usage: node ./scripts/startup.ts [--iterations <count>] [--top <count>]",
      { cause },
    );
  }
}

function runNeovim(arguments_: readonly string[]): void {
  execFileSync("nvim", ["--headless", ...arguments_], { stdio: "ignore" });
}

function percentile(sorted: readonly number[], fraction: number): number {
  return sorted[Math.ceil(sorted.length * fraction) - 1]!;
}

function parseStartupEntries(contents: string): readonly StartupEntry[] {
  return contents.split("\n").flatMap((line) => {
    const match = line.match(/^\s*\d+\.\d+\s+(\d+\.\d+)\s+(\d+\.\d+):\s+(.+)$/);
    if (!match) return [];

    return [
      {
        description: match[3]!,
        selfMilliseconds: Number(match[2]),
        totalMilliseconds: Number(match[1]),
      },
    ];
  });
}

/** Measures complete process startup and reports Neovim's slowest startup entries. */
export async function reportNeovimStartup({
  iterations,
  top,
}: StartupOptions): Promise<void> {
  const times: number[] = [];
  for (let index = 0; index < iterations; index += 1) {
    const startedAt = performance.now();
    runNeovim(["-c", "qa!"]);
    times.push(performance.now() - startedAt);
  }

  const sorted = times.toSorted((left, right) => left - right);
  const mean = times.reduce((total, value) => total + value, 0) / times.length;

  console.log(`Neovim startup (${iterations} runs)`);
  console.log(`min     ${sorted[0]!.toFixed(3)} ms`);
  console.log(`median  ${percentile(sorted, 0.5).toFixed(3)} ms`);
  console.log(`mean    ${mean.toFixed(3)} ms`);
  console.log(`p95     ${percentile(sorted, 0.95).toFixed(3)} ms`);
  console.log(`max     ${sorted.at(-1)!.toFixed(3)} ms`);

  const directory = await mkdtemp(join(tmpdir(), "dotkit-nvim-startup-"));
  const logPath = join(directory, "startuptime.log");

  try {
    runNeovim(["--startuptime", logPath, "-c", "qa!"]);
    const entries = parseStartupEntries(await readFile(logPath, "utf8"))
      .toSorted((left, right) => right.selfMilliseconds - left.selfMilliseconds)
      .slice(0, top);

    console.log(`\nTop ${top} startup entries by self time`);
    console.log("self(ms)  total(ms)  entry");
    for (const entry of entries) {
      console.log(
        `${entry.selfMilliseconds.toFixed(3).padStart(8)}  ${entry.totalMilliseconds.toFixed(3).padStart(9)}  ${entry.description}`,
      );
    }
  } finally {
    await rm(directory, { force: true, recursive: true });
  }
}

if (import.meta.main) {
  try {
    await reportNeovimStartup(parseStartupArguments(process.argv.slice(2)));
  } catch (cause) {
    const message = cause instanceof Error ? cause.message : String(cause);
    console.error(`NVIM_STARTUP_ERROR: ${message}`);
    process.exitCode = 1;
  }
}
