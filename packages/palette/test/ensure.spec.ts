import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, expect, it, vi } from "vitest";
import { ensureSchemes } from "../scripts/ensure";

const roots: string[] = [];
afterEach(async () => {
  vi.unstubAllGlobals();
  await Promise.all(
    roots.splice(0).map((root) => rm(root, { recursive: true, force: true })),
  );
});
async function fixture() {
  const root = await mkdtemp(join(tmpdir(), "palette-ensure-"));
  roots.push(root);
  return join(root, "base16");
}
it("validates existing input offline without replacing it", async () => {
  const destination = await fixture();
  await mkdir(destination);
  const source = [
    "system: base16",
    "name: Fixture",
    "author: Test",
    "variant: dark",
    "palette:",
    ...Array.from(
      { length: 16 },
      (_, i) =>
        `  base${i.toString(16).toUpperCase().padStart(2, "0")}: '#282c34'`,
    ),
  ].join("\n");
  await writeFile(join(destination, "fixture.yaml"), source);
  const fetch = vi.fn();
  vi.stubGlobal("fetch", fetch);
  await ensureSchemes(destination);
  expect(fetch).not.toHaveBeenCalled();
  expect(await readFile(join(destination, "fixture.yaml"), "utf8")).toBe(
    source,
  );
});
it("rejects invalid existing input without fetching or overwriting", async () => {
  const destination = await fixture();
  await mkdir(destination);
  await writeFile(join(destination, "broken.yaml"), "invalid");
  const fetch = vi.fn();
  vi.stubGlobal("fetch", fetch);
  await expect(ensureSchemes(destination)).rejects.toThrow();
  expect(fetch).not.toHaveBeenCalled();
  expect(await readFile(join(destination, "broken.yaml"), "utf8")).toBe(
    "invalid",
  );
});
it("reports failed downloads without publishing a partial collection", async () => {
  const destination = await fixture();
  vi.stubGlobal(
    "fetch",
    vi.fn().mockResolvedValue(new Response(null, { status: 503 })),
  );
  await expect(ensureSchemes(destination)).rejects.toThrow("HTTP 503");
  await expect(
    readFile(join(destination, "fixture.yaml")),
  ).rejects.toMatchObject({ code: "ENOENT" });
});
