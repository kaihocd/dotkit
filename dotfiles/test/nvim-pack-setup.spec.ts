import { execFile } from "node:child_process";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { promisify } from "node:util";
import { expect, it, onTestFinished } from "vitest";

const execute = promisify(execFile);
const cases = [
  {
    name: "setup without opts",
    source:
      "return {setup=function(o) assert(vim.deep_equal(o, {})); _G.called=true end}",
    spec: "",
    check: "assert(called)",
  },
  {
    name: "unchanged options",
    source:
      "return {setup=function(o) assert(rawequal(o, options)); _G.called=true end}",
    spec: "opts=options",
    check: "assert(called)",
  },
  {
    name: "cached module",
    source: "return {setup=function() _G.called=true end}",
    spec: "",
    before: "vim.cmd.packadd('fixture'); require('fixture')",
    check: "assert(called)",
  },
  {
    name: "custom config precedence",
    source: "error('must not require')",
    spec: "opts=options, config=function(o) assert(rawequal(o, options)); _G.called=true end",
    check: "assert(called); assert(package.loaded.fixture == nil)",
  },
  {
    name: "disabled configuration",
    source: "error('must not require')",
    spec: "config=false, opts=options",
    check: "assert(package.loaded.fixture == nil)",
  },
  {
    name: "self-initializing module",
    source: "_G.called=true; return {}",
    spec: "",
    check: "assert(called)",
  },
  {
    name: "Vimscript-only plugin",
    spec: "",
    check: "assert(vim.g.plugin_loaded)",
  },
  {
    name: "missing explicit entry",
    spec: "main='absent_pack_entry'",
    error: "fixture",
  },
  {
    name: "missing inferred entry with opts",
    spec: "opts={}",
    error: "fixture",
  },
  {
    name: "missing setup with opts",
    source: "return {}",
    spec: "opts={}",
    error: "has no setup function",
  },
  {
    name: "missing setup with main",
    source: "return {}",
    spec: "main='fixture'",
    error: "has no setup function",
  },
  {
    name: "module runtime error",
    source: "error('module exploded')",
    spec: "",
    error: "module exploded",
  },
  {
    name: "nested missing dependency",
    source: "require('absent_nested_pack_dependency')",
    spec: "",
    error: "absent_nested_pack_dependency",
  },
  {
    name: "setup error",
    source: "return {setup=function() error('setup exploded') end}",
    spec: "",
    error: "setup exploded",
  },
];

it.each(cases)("Pack automatic setup: $name", async (test) => {
  const home = await mkdtemp(join(tmpdir(), "pack-setup-"));
  onTestFinished(() => rm(home, { recursive: true, force: true }));
  const target = join(home, "data/nvim/site/pack/local/opt/fixture");
  await mkdir(join(target, "lua"), { recursive: true });
  await mkdir(join(target, "plugin"), { recursive: true });
  await writeFile(
    join(target, "plugin/fixture.lua"),
    "vim.g.plugin_loaded = true",
  );
  if (test.source)
    await writeFile(join(target, "lua/fixture.lua"), test.source);
  const script = join(home, "test.lua");
  await writeFile(
    script,
    `
vim.opt.runtimepath:prepend('${resolve(import.meta.dirname, "../configs/nvim-pack/pack.nvim")}')
_G.options = {nested={value=42}}
local state = require('pack.spec').build({{path='${target}', ${test.spec}}})
${test.before ?? ""}
local ok, err = pcall(require('pack.loader').setup, state)
${test.error ? `assert(not ok, 'expected configuration failure'); assert(tostring(err):find('${test.error}', 1, true), tostring(err)); assert(not state.registry.fixture.loaded)` : `assert(ok, tostring(err)); assert(state.registry.fixture.loaded); ${test.check}`}
`,
  );
  await expect(
    execute("nvim", ["--headless", "-u", "NONE", "-l", script], {
      env: {
        ...process.env,
        NVIM_APPNAME: "nvim",
        XDG_DATA_HOME: join(home, "data"),
        XDG_CONFIG_HOME: join(home, "config"),
        XDG_STATE_HOME: join(home, "state"),
        XDG_CACHE_HOME: join(home, "cache"),
      },
      timeout: 10000,
    }),
  ).resolves.toMatchObject({ stderr: "" });
});
