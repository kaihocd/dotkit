#!/usr/bin/env node

import { resolve } from "node:path";

import { runScript } from "@dotkit/shared/script";

import { createPalette } from "../src/create-palette";
import { run } from "./run";

async function main(): Promise<void> {
  const catalogDirectory = resolve(import.meta.dirname, "catalog");
  const result = await run(process.argv.slice(2), () =>
    createPalette({ catalogDirectory }),
  );
  process.stdout.write(result);
}

if (import.meta.main) {
  await runScript(main, { label: "PALETTE_ERROR" });
}
