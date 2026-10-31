import assert from "node:assert/strict";
import { test } from "node:test";
import { isMissingPackage, winget } from "../../src/software/winget";
import { prerequisite } from "./requirements";
import { profileContent } from "./profile";

test("WinGet missing-package detection uses unsigned HRESULT, not message text", () => {
  for (const code of [0x8a150014, 0x8a150014 | 0]) {
    assert.equal(isMissingPackage(Object.assign(new Error(), { code })), true);
  }
  assert.equal(isMissingPackage(new Error("0x8a150014")), false);
  assert.equal(
    isMissingPackage(Object.assign(new Error(), { code: "ENOENT" })),
    false,
  );
  assert.equal(
    isMissingPackage(Object.assign(new Error(), { code: 1 })),
    false,
  );
});

test("WinGet preserves exact nightly selection and explicit installer arguments", () => {
  const context = { cwd: process.cwd(), environment: {} };
  const command = winget.install("wez.wezterm.nightly").command(context);
  assert.deepEqual(command.args.slice(0, 6), [
    "install",
    "--id",
    "wez.wezterm.nightly",
    "--exact",
    "--source",
    "winget",
  ]);
  assert.deepEqual(
    winget
      .install("compiler", ["--override", "--add workload"])
      .command(context)
      .args.slice(-2),
    ["--override", "--add workload"],
  );
});

test("missing bootstrap utility blocks instead of proposing an installation", async () => {
  const utility = prerequisite("dotkit-nonexistent-utility", []);
  assert.equal(
    (await utility.inspect({ cwd: process.cwd(), environment: {} })).status,
    "blocked",
  );
  assert.deepEqual(utility.requirements, {
    network: false,
    elevatedPrivileges: false,
  });
});

test("Profile adds the complete Palette artifact directory to PATH", () => {
  const content = profileContent({
    home: "/home/test",
    binDirectory: "/home/test/.local/bin",
    xdg: {
      XDG_CONFIG_HOME: "/home/test/.config",
      XDG_DATA_HOME: "/home/test/.local/share",
      XDG_CACHE_HOME: "/home/test/.cache",
      XDG_STATE_HOME: "/home/test/.local/state",
    },
  });
  assert.match(content, /bin[/\\]palette/);
  assert.match(content, /\$env:PATH/);
});
