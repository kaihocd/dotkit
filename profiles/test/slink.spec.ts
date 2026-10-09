import {
  chmod,
  lstat,
  mkdtemp,
  readFile,
  readlink,
  rm,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { describe, expect, it, onTestFinished } from "vitest";

import { build } from "../scripts/build";
import { parseSlinkArguments, slink } from "../scripts/slink";

const HOME = "/Users/example";

describe("Profiles slink", () => {
  it("links and reloads the single built LaunchAgent", async () => {
    const root = await mkdtemp(join(tmpdir(), "dotkit-profiles-slink-"));
    const home = join(root, "home");
    const distributionDirectory = join(root, "dist");
    const log = join(root, "launchctl.log");
    const launchctl = join(root, "launchctl");
    onTestFinished(() => rm(root, { force: true, recursive: true }));

    await writeFile(launchctl, `#!/bin/sh\nprintf '%s\\n' "$*" >> '${log}'\n`);
    await chmod(launchctl, 0o755);
    await build({ home: HOME, distributionDirectory });
    await slink({
      home,
      uid: 501,
      distributionDirectory,
      launchctl,
      platform: "darwin",
    });

    const target = join(home, "Library", "LaunchAgents", "dev.qihao.xdg.plist");
    expect(await readlink(target)).toBe(
      join(distributionDirectory, "dev.qihao.xdg.plist"),
    );
    expect(await readFile(log, "utf8")).toBe(
      `bootout gui/501/dev.qihao.xdg\nbootstrap gui/501 ${target}\n`,
    );
  });

  it("previews without linking or invoking launchctl", async () => {
    const root = await mkdtemp(join(tmpdir(), "dotkit-profiles-preview-"));
    const home = join(root, "home");
    const distributionDirectory = join(root, "dist");
    const launchctl = join(root, "missing-launchctl");
    const target = join(home, "Library", "LaunchAgents", "dev.qihao.xdg.plist");
    onTestFinished(() => rm(root, { force: true, recursive: true }));

    await build({ home: HOME, distributionDirectory });
    await slink({
      onlyPreview: true,
      home,
      uid: 501,
      distributionDirectory,
      launchctl,
      platform: "darwin",
    });

    await expect(lstat(target)).rejects.toMatchObject({ code: "ENOENT" });
  });

  it("parses the optional preview flag with Node's strict argument grammar", () => {
    expect(parseSlinkArguments([])).toEqual({ onlyPreview: false });
    expect(parseSlinkArguments(["--only-preview"])).toEqual({
      onlyPreview: true,
    });
    expect(() => parseSlinkArguments(["--preview"])).toThrow(
      "Usage: pnpm slink [--only-preview]",
    );
  });

  it("rejects unsupported platforms before changing the filesystem", async () => {
    await expect(slink({ platform: "linux" })).rejects.toThrow(
      "Profiles symbolic-link installation is currently supported only on macOS.",
    );
  });
});
