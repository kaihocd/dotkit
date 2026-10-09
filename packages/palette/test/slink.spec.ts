import {
  lstat,
  mkdir,
  mkdtemp,
  readlink,
  rm,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { describe, expect, it, onTestFinished } from "vitest";

import { parseSlinkArguments, slink } from "../scripts/slink";

async function fixture() {
  const root = await mkdtemp(join(tmpdir(), "dotkit-palette-slink-"));
  const home = join(root, "home");
  const dataHome = join(root, "data");
  const distributionDirectory = join(root, "dist");
  const executable = join(distributionDirectory, "palette.js");
  const completion = join(distributionDirectory, "completions", "_palette");

  onTestFinished(() => rm(root, { force: true, recursive: true }));
  await mkdir(join(distributionDirectory, "completions"), { recursive: true });
  await Promise.all([
    writeFile(executable, "#!/usr/bin/env node\n"),
    writeFile(completion, "#compdef palette\n"),
  ]);

  return { home, dataHome, distributionDirectory, executable, completion };
}

describe("Palette slink", () => {
  it("links the executable and Zsh completion", async () => {
    const installation = await fixture();

    await slink(installation);

    await expect(
      readlink(join(installation.home, ".local", "bin", "palette")),
    ).resolves.toBe(installation.executable);
    await expect(
      readlink(
        join(installation.dataHome, "zsh", "site-functions", "_palette"),
      ),
    ).resolves.toBe(installation.completion);
  });

  it("previews both links without changing the filesystem", async () => {
    const installation = await fixture();

    await slink({ ...installation, onlyPreview: true });

    await expect(
      lstat(join(installation.home, ".local")),
    ).rejects.toMatchObject({
      code: "ENOENT",
    });
    await expect(
      lstat(join(installation.dataHome, "zsh")),
    ).rejects.toMatchObject({
      code: "ENOENT",
    });
  });

  it("accepts only the shared preview option", () => {
    expect(parseSlinkArguments(["--only-preview"])).toEqual({
      onlyPreview: true,
    });
    expect(() => parseSlinkArguments(["--preview"])).toThrow(
      "Usage: pnpm slink [--only-preview]",
    );
  });
});
