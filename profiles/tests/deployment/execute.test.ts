import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

import { executeDeployment } from "../../src/deployment/execute";
import { previewDeployment } from "../../src/deployment/preview";
import type {
  Installation,
  PlatformConfiguration,
} from "../../src/deployment/platform";

test("deployment hooks follow successful work and stop on failures", async () => {
  const home = await mkdtemp(join(tmpdir(), "dotkit-execution-"));
  try {
    const order: string[] = [];
    const xdg = {
      XDG_CONFIG_HOME: home,
      XDG_DATA_HOME: home,
      XDG_CACHE_HOME: home,
      XDG_STATE_HOME: home,
    };
    const source = join(home, "source");
    const installation: Installation = {
      target: "fake",
      environment: { home, xdg, binDirectory: home },
      software: [
        {
          name: "local",
          links: [{ source, target: join(home, "link") }],
          build: {
            requirements: { network: false, elevatedPrivileges: false },
            run: async (context) => {
              assert.equal(context.environment.HOME, home);
              assert.equal(context.environment.XDG_STATE_HOME, home);
              assert.equal(context.cwd, home);
              order.push("build");
              await writeFile(source, "generated");
            },
          },
        },
      ],
    };
    const platform: PlatformConfiguration = {
      target: "fake",
      environment: { defaults: xdg, binDirectory: home },
      software: () => installation.software,
      preInstall: async (context) => {
        if (context.onlyPreview) return;
        order.push("pre");
      },
      postInstall: async () => {
        order.push("post");
      },
    };
    const options = {
      cwd: home,
      variables: {},
      authorize: {
        deployment: true,
        network: false,
        elevatedPrivileges: false,
      },
    };
    await assert.rejects(
      executeDeployment(platform, installation, {
        ...options,
        authorize: { ...options.authorize, deployment: false },
      }),
      /authorization/,
    );
    assert.equal(order.length, 0);
    await writeFile(join(home, "link"), "user file");
    await assert.rejects(
      executeDeployment(platform, installation, options),
      /Preflight blocked/,
    );
    assert.equal(order.length, 0);
    await rm(join(home, "link"));
    const success = await executeDeployment(platform, installation, options);
    assert.deepEqual(order, ["pre", "build", "post"]);
    assert.ok(success.steps.every((step) => step.status === "completed"));
    await executeDeployment(platform, installation, options);
    assert.equal(order.filter((step) => step === "build").length, 2);
    const preFailure = await executeDeployment(
      {
        ...platform,
        preInstall: async () => {
          throw new Error("pre failed");
        },
      },
      installation,
      options,
    );
    assert.ok(preFailure.steps.every((step) => step.status === "not-run"));
    assert.equal(preFailure.hooks.at(-1)?.status, "not-run");
    await rm(source);
    const missingOutput: Installation = {
      ...installation,
      software: [
        {
          ...installation.software[0]!,
          build: {
            requirements: { network: false, elevatedPrivileges: false },
            run: async () => {},
          },
        },
      ],
    };
    const failure = await executeDeployment(platform, missingOutput, options);
    assert.equal(failure.steps[0]?.status, "failed");
    assert.equal(failure.steps[1]?.status, "not-run");
    assert.equal(failure.hooks.at(-1)?.status, "not-run");
    const postFailure = await executeDeployment(
      {
        ...platform,
        postInstall: async () => {
          throw new Error("post failed");
        },
      },
      installation,
      options,
    );
    assert.equal(postFailure.hooks.at(-1)?.status, "failed");
    assert.ok(postFailure.steps.every((step) => step.status === "completed"));
    let probes = 0;
    const missingInstall: Installation = {
      ...installation,
      software: [
        {
          name: "fake-command",
          links: [],
          install: {
            requirements: { network: false, elevatedPrivileges: false },
            command: (context) => ({
              executable: process.execPath,
              args: ["-e", "process.exit(0)"],
              cwd: context.cwd,
              environment: context.environment,
            }),
            inspect: async () => {
              probes++;
              return { status: "missing" };
            },
          },
        },
      ],
    };
    const missing = await executeDeployment(platform, missingInstall, options);
    assert.equal(probes, 3);
    assert.equal(missing.steps[0]?.status, "failed");
    assert.equal(missing.steps[1]?.status, "not-run");
    assert.equal(missing.hooks.at(-1)?.status, "not-run");
    // Keep the original fixture unchanged for subsequent assertions.
    /* oxlint-disable no-map-spread */
    const denied = {
      ...missingInstall,
      software: missingInstall.software.map((entry) => ({
        ...entry,
        install: {
          ...entry.install!,
          requirements: { network: true, elevatedPrivileges: false },
        },
      })),
    };
    /* oxlint-enable no-map-spread */
    const count = order.length;
    await assert.rejects(
      executeDeployment(platform, denied, options),
      /not authorized/,
    );
    assert.equal(order.length, count);
    const preview = await previewDeployment(
      {
        ...platform,
        preInstall: async (context) => {
          assert.equal(context.onlyPreview, true);
          throw new Error("Existing link");
        },
        postInstall: async () => {
          throw new Error("Must not run");
        },
      },
      installation,
      options,
    );
    assert.equal(preview.hooks.preInstall?.status, "blocked");
    assert.equal(preview.hooks.postInstall?.status, "not-run");
    assert.equal(preview.software.length, 1);
  } finally {
    await rm(home, { recursive: true, force: true });
  }
});
