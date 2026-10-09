import {
  lstat,
  mkdir,
  mkdtemp,
  readlink,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

import { describe, expect, it, onTestFinished, vi } from "vitest";

import { ExpectedError } from "../src/error";
import { symbolicLink, type SymbolicLinkEvent } from "../src/link";

async function fixture() {
  const root = await mkdtemp(join(tmpdir(), "dotkit-link-"));
  const source = join(root, "source");
  const target = join(root, "nested", "target");
  await writeFile(source, "source");
  onTestFinished(() => rm(root, { force: true, recursive: true }));
  return { root, source, target };
}

describe("symbolicLink", () => {
  it("previews before creating missing links", async () => {
    const value = await fixture();

    const events: SymbolicLinkEvent[] = [];
    await symbolicLink([value], { observe: (event) => events.push(event) });

    expect(events).toEqual([
      {
        phase: "preview",
        action: "link",
        source: value.source,
        target: value.target,
      },
      {
        phase: "completed",
        action: "link",
        source: value.source,
        target: value.target,
      },
    ]);
    await expect(readlink(value.target)).resolves.toBe(value.source);
  });

  it("keeps links that already point to their source", async () => {
    const value = await fixture();
    await mkdir(dirname(value.target), { recursive: true });
    await symlink(value.source, value.target);

    await symbolicLink([value]);

    await expect(readlink(value.target)).resolves.toBe(value.source);
  });

  it("updates links that point elsewhere", async () => {
    const value = await fixture();
    const previous = join(value.root, "previous");
    await writeFile(previous, "previous");
    await mkdir(dirname(value.target), { recursive: true });
    await symlink(previous, value.target);

    await symbolicLink([value]);

    await expect(readlink(value.target)).resolves.toBe(value.source);
  });

  it("does not replace files or directories", async () => {
    const value = await fixture();
    await mkdir(dirname(value.target), { recursive: true });
    await writeFile(value.target, "occupied");

    await expect(symbolicLink([value])).rejects.toThrow(ExpectedError);
    await expect(lstat(value.target)).resolves.toMatchObject({
      isFile: expect.any(Function),
    });
  });

  it("validates every link before writing any target", async () => {
    const first = await fixture();
    const missing = join(first.root, "missing");

    await expect(
      symbolicLink([
        first,
        { source: missing, target: join(first.root, "second-target") },
      ]),
    ).rejects.toThrow("source does not exist");
    await expect(lstat(first.target)).rejects.toMatchObject({ code: "ENOENT" });
  });

  it("previews changes without writing", async () => {
    const value = await fixture();

    const events: SymbolicLinkEvent[] = [];
    await symbolicLink([value], {
      onlyPreview: true,
      observe: (event) => events.push(event),
    });

    expect(events).toEqual([
      {
        phase: "preview",
        action: "link",
        source: value.source,
        target: value.target,
      },
    ]);
    await expect(lstat(value.target)).rejects.toMatchObject({ code: "ENOENT" });
  });

  it("is silent unless an observer is explicitly supplied", async () => {
    const value = await fixture();
    const stdout = vi.spyOn(process.stdout, "write");
    const stderr = vi.spyOn(process.stderr, "write");

    await symbolicLink([value]);

    expect(stdout).not.toHaveBeenCalled();
    expect(stderr).not.toHaveBeenCalled();
    stdout.mockRestore();
    stderr.mockRestore();
  });

  it("rejects relative paths and duplicate targets", async () => {
    const value = await fixture();

    await expect(
      symbolicLink([{ source: "source", target: value.target }]),
    ).rejects.toThrow("source must be absolute");
    await expect(
      symbolicLink([value, { source: value.source, target: value.target }]),
    ).rejects.toThrow("Duplicate symbolic link target");
  });
});
