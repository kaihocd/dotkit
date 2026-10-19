import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import {
  access,
  mkdtemp,
  readFile,
  readlink,
  realpath,
  rm,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { promisify } from "node:util";

import { executeDeployment } from "../../src/deployment/execute";
import type {
  Installation,
  PlatformConfiguration,
} from "../../src/deployment/platform";

const exec = promisify(execFile);

test("real child processes receive resolved environment without changing the parent", async () => {
  const home = await realpath(
    await mkdtemp(join(tmpdir(), "dotkit-acceptance-")),
  );
  const parent = { ...process.env };
  try {
    const xdg = {
      XDG_CONFIG_HOME: join(home, "config"),
      XDG_DATA_HOME: join(home, "data"),
      XDG_CACHE_HOME: join(home, "cache"),
      XDG_STATE_HOME: join(home, "state"),
    };
    const installed = join(home, "installed.json");
    const built = join(home, "built.json");
    const snapshot =
      "JSON.stringify({HOME:process.env.HOME,XDG_CONFIG_HOME:process.env.XDG_CONFIG_HOME,XDG_DATA_HOME:process.env.XDG_DATA_HOME,XDG_CACHE_HOME:process.env.XDG_CACHE_HOME,XDG_STATE_HOME:process.env.XDG_STATE_HOME,cwd:process.cwd()})";
    let post = 0;
    const installation: Installation = {
      target: "acceptance",
      environment: { home, xdg, binDirectory: join(home, "bin") },
      software: [
        {
          name: "fixture",
          install: {
            requirements: { network: false, elevatedPrivileges: false },
            command: (context) => ({
              executable: process.execPath,
              args: [
                "-e",
                `require('node:fs').writeFileSync(${JSON.stringify(installed)},${snapshot})`,
              ],
              cwd: context.cwd,
              environment: context.environment,
            }),
            inspect: async () => {
              try {
                await access(installed);
                return { status: "installed" };
              } catch {
                return { status: "missing" };
              }
            },
          },
          build: {
            requirements: { network: false, elevatedPrivileges: false },
            run: async (context) => {
              await exec(
                process.execPath,
                [
                  "-e",
                  `require('node:fs').writeFileSync(${JSON.stringify(built)},${snapshot})`,
                ],
                { cwd: context.cwd, env: context.environment },
              );
            },
          },
          links: [{ source: built, target: join(home, "result") }],
        },
      ],
    };
    const platform: PlatformConfiguration = {
      target: installation.target,
      environment: { defaults: xdg, binDirectory: home },
      software: () => installation.software,
      postInstall: async () => {
        post++;
      },
    };
    const options = {
      cwd: home,
      variables: { HOME: "/wrong", XDG_STATE_HOME: "/wrong" },
      authorize: {
        deployment: true,
        network: false,
        elevatedPrivileges: false,
      },
    };
    const first = await executeDeployment(platform, installation, options);
    assert.ok(first.steps.every((step) => step.status === "completed"));
    assert.deepEqual(JSON.parse(await readFile(installed, "utf8")), {
      HOME: home,
      ...xdg,
      cwd: home,
    });
    assert.deepEqual(JSON.parse(await readFile(built, "utf8")), {
      HOME: home,
      ...xdg,
      cwd: home,
    });
    assert.equal(await readlink(join(home, "result")), built);
    const second = await executeDeployment(platform, installation, options);
    assert.equal(second.steps[0]?.status, "skipped");
    assert.equal(post, 2);
    assert.deepEqual({ ...process.env }, parent);
  } finally {
    await rm(home, { recursive: true, force: true });
  }
});
