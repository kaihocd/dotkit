import { mkdtemp, readdir, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { parse } from "plist";
import { describe, expect, it, onTestFinished } from "vitest";

import { build } from "../scripts/build";

const HOME = "/Users/example";

describe("Profiles build", () => {
  it("replaces dist with one LaunchAgent and its generated helper", async () => {
    const root = await mkdtemp(join(tmpdir(), "dotkit-profiles-build-"));
    const distributionDirectory = join(root, "dist");
    onTestFinished(() => rm(root, { force: true, recursive: true }));

    await build({ home: HOME, distributionDirectory });

    expect(await readdir(distributionDirectory)).toEqual([
      "dev.qihao.xdg.plist",
      "set-xdg-environment.sh",
    ]);

    const helper = join(distributionDirectory, "set-xdg-environment.sh");
    const document = parse(
      await readFile(
        join(distributionDirectory, "dev.qihao.xdg.plist"),
        "utf8",
      ),
    );
    expect(document).toMatchObject({
      Label: "dev.qihao.xdg",
      ProgramArguments: ["/bin/sh", helper],
    });
    expect(await readFile(helper, "utf8")).toContain(
      "/bin/launchctl setenv XDG_CONFIG_HOME '/Users/example/.config'",
    );
  });
});
