import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { ExpectedError } from "@dotkit/shared/error";
import { describe, expect, it, onTestFinished } from "vitest";

import { readBase16Schemes } from "../scripts/schemes/base16";

const palette = Object.fromEntries(
  Array.from({ length: 16 }, (_, index) => [
    `base${index.toString(16).toUpperCase().padStart(2, "0")}`,
    `#${index.toString(16).padStart(6, "0")}`,
  ]),
);

function scheme(name: string) {
  return {
    system: "base16",
    name,
    author: "Dotkit",
    variant: "dark",
    palette,
  };
}

async function createFixture() {
  const directory = await mkdtemp(join(tmpdir(), "dotkit-palette-base16-"));

  onTestFinished(async () => {
    await rm(directory, { force: true, recursive: true });
  });

  return directory;
}

async function writeYaml(
  directory: string,
  file: string,
  value: unknown,
): Promise<void> {
  await writeFile(join(directory, file), JSON.stringify(value));
}

describe("readBase16Schemes", () => {
  it("requires an absolute schemes directory", async () => {
    await expect(readBase16Schemes("base16")).rejects.toThrow(ExpectedError);
  });

  it("returns validated schemes sorted by their filename ID", async () => {
    const directory = await createFixture();
    await writeYaml(directory, "zeta.yaml", scheme("Zeta"));
    await writeYaml(directory, "alpha.yml", scheme("Alpha"));
    await writeFile(join(directory, "README.md"), "ignored");

    await expect(readBase16Schemes(directory)).resolves.toEqual([
      {
        id: "alpha",
        source: "base16/alpha.yml",
        scheme: scheme("Alpha"),
      },
      {
        id: "zeta",
        source: "base16/zeta.yaml",
        scheme: scheme("Zeta"),
      },
    ]);
  });

  it("accepts uppercase hex colors from Base16", async () => {
    const directory = await createFixture();
    const input = scheme("Uppercase");
    input.palette.base00 = "#ABCDEF";
    await writeYaml(directory, "uppercase.yaml", input);

    await expect(readBase16Schemes(directory)).resolves.toHaveLength(1);
  });

  it("reports an empty schemes directory as an expected error", async () => {
    const directory = await createFixture();

    await expect(readBase16Schemes(directory)).rejects.toThrow(ExpectedError);
  });

  it("reports an invalid scheme with its source path", async () => {
    const directory = await createFixture();
    await writeYaml(directory, "broken.yaml", {
      ...scheme("Broken"),
      system: "base24",
    });

    await expect(readBase16Schemes(directory)).rejects.toThrow(
      "Invalid Base16 scheme base16/broken.yaml",
    );
  });

  it("rejects a filename that is not a valid theme ID", async () => {
    const directory = await createFixture();
    await writeYaml(directory, "Invalid Name.yaml", scheme("Invalid"));

    await expect(readBase16Schemes(directory)).rejects.toThrow(
      "Invalid Base16 theme ID: Invalid Name",
    );
  });

  it("rejects duplicate IDs across yaml extensions", async () => {
    const directory = await createFixture();
    await writeYaml(directory, "duplicate.yaml", scheme("First"));
    await writeYaml(directory, "duplicate.yml", scheme("Second"));

    await expect(readBase16Schemes(directory)).rejects.toThrow(
      "Duplicate Base16 theme ID: duplicate",
    );
  });

  it("reports a missing schemes directory as an expected error", async () => {
    const root = await createFixture();
    const directory = join(root, "missing");

    await expect(readBase16Schemes(directory)).rejects.toThrow(ExpectedError);
  });
});
