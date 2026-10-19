import assert from "node:assert/strict";
import {
  mkdtemp,
  readFile,
  readdir,
  readlink,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

import type { PlatformContext } from "../../../src/deployment/platform";
import {
  deployXdgEnvironment,
  type Launchctl,
} from "../../../platforms/macos/launch-agent";

test("macOS environment preview and repeat deployment use only the supplied command boundary", async () => {
  const home = await mkdtemp(join(tmpdir(), "dotkit-xdg-"));
  try {
    const context: PlatformContext = {
      cwd: home,
      variables: {},
      onlyPreview: true,
      environment: {
        home,
        binDirectory: join(home, "bin"),
        xdg: {
          XDG_CONFIG_HOME: join(home, "config"),
          XDG_DATA_HOME: join(home, "data"),
          XDG_CACHE_HOME: join(home, "cache"),
          XDG_STATE_HOME: join(home, "state"),
        },
      },
    };
    const calls: string[] = [];
    const values = new Map<string, string>();
    let loaded = false;
    const run: Launchctl = async (args) => {
      calls.push(args.join(" "));
      if (args[0] === "print" && args[1]?.includes("dev.qihao") && !loaded)
        throw new Error("Absent");
      if (args[0] === "bootstrap") loaded = true;
      if (args[0] === "bootout") loaded = false;
      if (args[0] === "setenv") values.set(args[1]!, args[2]!);
      return args[0] === "getenv" ? `${values.get(args[1]!)}\n` : "";
    };
    await deployXdgEnvironment(context, run, 501);
    assert.equal(calls.length, 0);
    assert.deepEqual(await readdir(home), []);
    const execute = { ...context, onlyPreview: false };
    await deployXdgEnvironment(execute, run, 501);
    assert.equal(values.size, 4);
    const helper = join(home, "config/environment/xdg.sh");
    assert.match(await readFile(helper, "utf8"), /launchctl setenv/);
    await deployXdgEnvironment(execute, run, 501);
    assert.ok(calls.includes("bootout gui/501/dev.qihao.xdg"));
    await assert.rejects(
      deployXdgEnvironment(
        execute,
        async () => {
          throw new Error("Denied");
        },
        501,
      ),
      /Denied/,
    );
    await assert.rejects(
      deployXdgEnvironment(
        execute,
        async (args) => {
          if (args[0] === "getenv") return "wrong-value\n";
          return run(args);
        },
        501,
      ),
      /environment verification failed/,
    );
    const plist = join(home, "Library/LaunchAgents/dev.qihao.xdg.plist");
    const legacy = join(home, "legacy.plist");
    await writeFile(legacy, "legacy content");
    await rm(plist);
    await symlink(legacy, plist);
    calls.length = 0;
    await assert.rejects(
      deployXdgEnvironment(execute, run, 501),
      /Existing symlink/,
    );
    assert.equal(calls.length, 0);
    assert.equal(await readlink(plist), legacy);
    assert.equal(await readFile(legacy, "utf8"), "legacy content");
    await rm(plist);
    await writeFile(helper, "user owned");
    calls.length = 0;
    await assert.rejects(deployXdgEnvironment(execute, run, 501), /unmanaged/);
    assert.equal(calls.length, 0);
    assert.equal(await readFile(helper, "utf8"), "user owned");
  } finally {
    await rm(home, { recursive: true, force: true });
  }
});
