import { readdir, stat } from "node:fs/promises";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

import type { PlatformConfiguration } from "./platform";

/** Only direct platform directories with an install.ts entry are discoverable. */
export class PlatformLoader {
  constructor(
    private readonly directory = resolve(
      import.meta.dirname,
      "../../platforms",
    ),
  ) {}

  async discover(): Promise<ReadonlyMap<string, string>> {
    const directory = this.directory;
    const entries = await readdir(directory, { withFileTypes: true });
    const platforms = new Map<string, string>();
    for (const entry of entries.toSorted((a, b) =>
      a.name.localeCompare(b.name),
    )) {
      if (!entry.isDirectory()) continue;
      const file = join(directory, entry.name, "install.ts");
      try {
        // oxlint-disable-next-line no-await-in-loop
        if ((await stat(file)).isFile()) platforms.set(entry.name, file);
      } catch (error) {
        if (!(
          error instanceof Error &&
          "code" in error &&
          error.code === "ENOENT"
        ))
          throw error;
      }
    }
    return platforms;
  }

  /** Import only a discovered entry, never a path constructed from CLI input. */
  async load(
    name: string,
    platforms: ReadonlyMap<string, string>,
  ): Promise<PlatformConfiguration> {
    const file = platforms.get(name);
    if (!file) {
      throw new Error(
        `Unknown platform "${name}". Available: ${[...platforms.keys()].join(", ")}`,
      );
    }
    const module = await import(pathToFileURL(file).href);
    const configuration = module.default;
    if (!configuration || typeof configuration !== "object") {
      throw new TypeError(
        `Platform "${name}" must default-export a configuration object.`,
      );
    }
    return configuration as PlatformConfiguration;
  }
}
