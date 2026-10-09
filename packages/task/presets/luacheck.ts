import { execFile, spawn } from "node:child_process";
import { promisify } from "node:util";
import { mkdtemp, readFile, readdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, relative, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import type { TaskDefinition } from "../src/types";
import { duration, styled } from "../src/rendering/output";
import { commandDefinition } from "./common";
const CONFIG_NAME = ".luarc.json";
const IGNORED_DIRECTORIES = new Set(["node_modules", ".git", "dist"]);
const LUA_SERVER_ARGS = ["--check=.", "--checklevel=Hint"] as const;

type LuaDiagnostic = {
  readonly code?: string;
  readonly severity?: number;
  readonly message: string;
  readonly range?: {
    readonly start?: {
      readonly line?: number;
      readonly character?: number;
    };
  };
};

type LuaReport = Record<string, readonly LuaDiagnostic[]>;

const SEVERITIES = ["Error", "Warning", "Information", "Hint"] as const;

function diagnosticSeverity(
  value?: number,
): (typeof SEVERITIES)[number] | "Diagnostic" {
  return SEVERITIES[(value ?? 0) - 1] ?? "Diagnostic";
}

function diagnosticFile(file: string): string {
  return file.startsWith("file:") ? fileURLToPath(file) : file;
}

export interface LuaCheckTarget {
  readonly directory: string;
}

/** Discovers independent .luarc.json workspaces, without following symlinks. */
export async function findLuaCheckTargets(
  rootDirectory: string,
): Promise<readonly LuaCheckTarget[]> {
  const targets: LuaCheckTarget[] = [];

  async function visit(directory: string): Promise<void> {
    const entries = await readdir(directory, { withFileTypes: true });
    const childDirectories: Promise<void>[] = [];
    for (const entry of entries) {
      if (entry.isDirectory()) {
        if (!IGNORED_DIRECTORIES.has(entry.name)) {
          childDirectories.push(visit(join(directory, entry.name)));
        }
        continue;
      }
      if (entry.isFile() && entry.name === CONFIG_NAME) {
        targets.push({
          directory,
        });
      }
    }
    await Promise.all(childDirectories);
  }

  await visit(resolve(rootDirectory));
  return targets.toSorted((left, right) =>
    left.directory.localeCompare(right.directory),
  );
}

export interface LuaCheckResult {
  readonly target: LuaCheckTarget;
  readonly exitCode: number;
  readonly output: string;
  readonly diagnosticCount: number;
  readonly durationMs: number;
}

/** Formats a diagnostic with a workspace-relative label and an absolute file link. */
function formatDiagnostic(
  targetDirectory: string,
  file: string,
  diagnostic: LuaDiagnostic,
): string {
  const filePath = diagnosticFile(file);
  const position = diagnostic.range?.start;
  // LuaLS positions are zero-based; terminal locations are one-based.
  const location =
    position?.line === undefined
      ? ""
      : `:${position.line + 1}:${(position.character ?? 0) + 1}`;
  const severity = diagnosticSeverity(diagnostic.severity);
  const severityStyle =
    severity === "Error"
      ? "red"
      : severity === "Warning"
        ? "yellow"
        : severity === "Information"
          ? "blue"
          : "gray";
  // OSC 8 opens the file; displayed line/column numbers are not part of the link target.
  const locationLink = `\u001B]8;;${pathToFileURL(filePath).href}\u0007${relative(targetDirectory, filePath)}${location}\u001B]8;;\u0007`;
  return [
    `  Diagnostic: ${locationLink}`,
    `    Severity: ${styled(severity, severityStyle)}`,
    `    Rule: ${diagnostic.code ?? "diagnostic"}`,
    ...diagnostic.message.split(/\r?\n/u).map((line) => `    ${line.trim()}`),
  ].join("\n");
}

/** Runs LuaLS with the target's own config and returns a buffered diagnostic block. */
export async function checkLuaTarget(
  target: LuaCheckTarget,
  executable = "lua-language-server",
): Promise<LuaCheckResult> {
  const startedAt = Date.now();
  const directory = await mkdtemp(join(tmpdir(), "dotkit-luacheck-"));
  const reportPath = join(directory, "report.json");
  try {
    const env = { ...process.env };
    const config = await readFile(join(target.directory, CONFIG_NAME), "utf8");
    if (!env.VIMRUNTIME && config.includes("$VIMRUNTIME")) {
      const { stdout } = await promisify(execFile)("nvim", [
        "--headless",
        "-u",
        "NONE",
        "+lua io.stdout:write(vim.env.VIMRUNTIME)",
        "+qa!",
      ]);
      env.VIMRUNTIME = stdout.trim();
      if (!env.VIMRUNTIME) throw new Error("Neovim did not report VIMRUNTIME");
    }
    const result = await new Promise<{ exitCode: number; output: string }>(
      (resolveResult) => {
        const child = spawn(
          executable,
          [
            ...LUA_SERVER_ARGS,
            "--check_format=json",
            `--check_out_path=${reportPath}`,
          ],
          {
            // --check=. lets LuaLS load this workspace's .luarc.json.
            cwd: target.directory,
            env,
            stdio: ["ignore", "pipe", "pipe"],
          },
        );
        const chunks: string[] = [];
        const collect = (chunk: string) => chunks.push(chunk);
        child.stdout.setEncoding("utf8").on("data", collect);
        child.stderr.setEncoding("utf8").on("data", collect);
        child.once("error", (error) => chunks.push(`${error.message}\n`));
        // Wait for both output streams to drain, not just process exit.
        child.once("close", (code) => {
          resolveResult({ exitCode: code ?? 1, output: chunks.join("") });
        });
      },
    );
    let output = "";
    let diagnosticCount = 0;
    try {
      // Consume the JSON report instead of parsing LuaLS's progress-filled stdout.
      const report = JSON.parse(
        await readFile(reportPath, "utf8"),
      ) as LuaReport;
      diagnosticCount = Object.values(report).reduce(
        (count, items) => count + items.length,
        0,
      );
      output = Object.entries(report)
        .flatMap(([file, items]) =>
          items.map((item) => formatDiagnostic(target.directory, file, item)),
        )
        .join("\n\n");
    } catch {
      // Preserve startup/report failures as raw output when no usable report exists.
      output = result.output.trim() || "LuaLS did not produce a report.";
    }
    return {
      target,
      exitCode: result.exitCode,
      output,
      diagnosticCount,
      durationMs: Date.now() - startedAt,
    };
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
}

/** Prints one completed workspace; only our own tree lines receive structural color. */
function printLuaCheckResult(
  rootDirectory: string,
  result: LuaCheckResult,
): void {
  const label = relative(rootDirectory, result.target.directory) || ".";
  console.log(`\n${styled(`[${label}]`, "bold")}`);
  if (result.output) {
    process.stdout.write(
      `${result.output
        .split("\n")
        .map((line) => `${styled("│", "gray")}  ${line}`)
        .join("\n")}\n`,
    );
  }
  console.log(
    `${styled("└─", "gray")} ${
      result.exitCode === 0
        ? styled(`Passed · Done in ${duration(result.durationMs)}`, "green")
        : styled(`Failed: ${result.diagnosticCount} diagnostics`, "red")
    }`,
  );
}

/** Checks workspaces in parallel, printing and returning results in completion order. */
export async function typecheckLua(
  rootDirectory = process.cwd(),
): Promise<readonly LuaCheckResult[]> {
  const targets = await findLuaCheckTargets(rootDirectory);
  if (targets.length === 0) {
    console.log("No .luarc.json files found; skipping Lua typecheck.");
    return [];
  }

  const results: LuaCheckResult[] = [];
  await Promise.all(
    targets.map(async (target) => {
      const result = await checkLuaTarget(target);
      results.push(result);
      printLuaCheckResult(rootDirectory, result);
    }),
  );
  return results;
}

/** Launches this preset's runner without depending on a project package script. */
export function luacheck(): TaskDefinition {
  return commandDefinition("luacheck", (context) => ({
    executable: "pnpm",
    args: ["exec", "tsx", resolve(import.meta.filename)],
    cwd: context.project.directory,
  }));
}

if (import.meta.main) {
  const results = await typecheckLua();
  if (results.some(({ exitCode }) => exitCode !== 0)) process.exitCode = 1;
}
