import { execFile, spawn } from "node:child_process";
import {
  lstat,
  mkdir,
  mkdtemp,
  readlink,
  rename,
  rm,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { promisify } from "node:util";

import { expect, it, onTestFinished } from "vitest";

const executeFile = promisify(execFile);
const configHome = resolve(import.meta.dirname, "../configs");
const theme = {
  id: "dotkit-test",
  name: "Dotkit Test",
  variant: "dark",
  palette: {
    ...Object.fromEntries(
      Array.from({ length: 24 }, (_, index) => [
        `base${index.toString(16).toUpperCase().padStart(2, "0")}`,
        `#${(index + 1).toString(16).padStart(6, "0")}`,
      ]),
    ),
    base07: "#111111",
    base09: "#eeeeee",
    base10: "#dddddd",
  },
};

const startupAssertions = [
  "assert(vim.g.mapleader == ' ')",
  "assert(vim.g.maplocalleader == ' ')",
  "assert(vim.fn.maparg('=', 'n') == '')",
  "assert(vim.fn.maparg('<leader>e', 'n') == '')",
  "assert(vim.fn.maparg('j', 'x') ~= '')",
  "assert(vim.fn.maparg('j', 's') == '')",
  "assert(vim.fn.maparg('J', 's') == '')",
  "assert(vim.fn.maparg('<Esc>', 'i') == '')",
  "assert(vim.fn.maparg('<Esc>', 's') == '')",
  "assert(vim.fn.maparg('<leader><Tab><Tab>', 'n') == '<Cmd>tab split<CR>')",
  "assert(vim.fn.maparg('q', 'n') == '<Nop>')",
  "assert(type(vim.fn.maparg('<leader>q', 'n', false, true).callback) == 'function')",
  "assert(vim.fn.maparg(':', 'n') == '')",
  "assert(vim.fn.maparg('/', 'n') == '')",
  "assert(vim.fn.maparg('?', 'n') == '')",
  "assert(vim.o.incsearch)",
  "assert(vim.o.cedit == string.char(6))",
  "assert(vim.fn.maparg('<C-f>', 'c') == '')",
  "assert(vim.o.cmdwinheight == 1)",
  "assert(#vim.api.nvim_get_autocmds({ event = 'CmdwinEnter', group = 'ConfigsCmdwin' }) == 1)",
  "assert(vim.wait(1000, function() return vim.o.background == 'dark' and vim.api.nvim_get_hl(0, { name = 'Normal' }).bg == 0x000001 end))",
  "assert(vim.api.nvim_get_hl(0, { name = 'Normal' }).bg == 0x000001)",
  "assert(vim.api.nvim_get_hl(0, { name = 'Normal' }).fg == 0x000006)",
  "assert(vim.api.nvim_get_hl(0, { name = 'Function' }).fg == 0x00000e)",
  "assert(vim.api.nvim_get_hl(0, { name = 'IncSearch' }).fg == 0x111111)",
  "assert(vim.api.nvim_get_hl(0, { name = 'Pmenu' }).fg == 0x000006)",
  "assert(vim.api.nvim_get_hl(0, { name = 'Ignore' }).fg == 0x000001)",
  "assert(vim.g.terminal_color_1 == '#000009')",
  "assert(vim.g.terminal_color_9 == '#000013')",
]
  .map(
    (assertion, index) =>
      `do local ok, err = pcall(function() ${assertion} end); assert(ok, 'startup assertion ${index + 1}: ' .. tostring(err)) end`,
  )
  .join("; ");

async function createRuntimeHome() {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const paletteDirectory = join(runtimeHome, "state", "palette");
  await mkdir(paletteDirectory, { recursive: true });
  return { paletteDirectory, runtimeHome };
}

function neovimEnvironment(runtimeHome: string) {
  return {
    ...process.env,
    XDG_CONFIG_HOME: configHome,
    XDG_DATA_HOME: join(runtimeHome, "data"),
    XDG_CACHE_HOME: join(runtimeHome, "cache"),
    XDG_STATE_HOME: join(runtimeHome, "state"),
  };
}

function packTestEnvironment(runtimeHome: string) {
  return {
    ...neovimEnvironment(runtimeHome),
    XDG_CONFIG_HOME: join(runtimeHome, "config"),
  };
}

it("starts quietly when the Palette state directory is missing", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));

  await expect(
    executeFile("nvim", ["--headless", "+qa!"], {
      env: neovimEnvironment(runtimeHome),
    }),
  ).resolves.toMatchObject({ stderr: "" });
});

it("bootstraps Pack for the current Neovim app without installing other plugins", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));

  const target = join(
    runtimeHome,
    "data",
    "nvim",
    "site",
    "pack",
    "dotkit",
    "opt",
    "pack.nvim",
  );
  const assertions = [
    "assert(vim.fn.exists(':PackStatus') == 2)",
    "assert(vim.fn.exists(':PackSync') == 2)",
    "assert(vim.fn.exists(':PackBuild') == 2)",
    "assert(vim.fn.exists(':PackClean') == 2)",
  ].join("; ");

  await expect(
    executeFile("nvim", ["--headless", `+lua ${assertions}`, "+qa!"], {
      env: neovimEnvironment(runtimeHome),
    }),
  ).resolves.toMatchObject({ stderr: "" });
  await expect(readlink(target)).resolves.toBe(
    resolve(configHome, "nvim-pack/pack.nvim"),
  );
  await expect(
    lstat(
      join(
        runtimeHome,
        "data",
        "nvim",
        "site",
        "pack",
        "dotkit",
        "opt",
        "popup.nvim",
      ),
    ),
  ).rejects.toMatchObject({ code: "ENOENT" });
});

it("isolates the Pack bootstrap by NVIM_APPNAME", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const isolatedConfigHome = join(runtimeHome, "config");
  const sourceConfig = resolve(configHome, "nvim");
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));
  await mkdir(isolatedConfigHome, { recursive: true });
  await Promise.all(
    ["nvim", "nvim-test"].map((name) =>
      import("node:fs/promises").then(({ symlink }) =>
        symlink(sourceConfig, join(isolatedConfigHome, name)),
      ),
    ),
  );

  await Promise.all(
    ["nvim", "nvim-test"].map(async (appName) => {
      const environment = {
        ...neovimEnvironment(runtimeHome),
        NVIM_APPNAME: appName,
        XDG_CONFIG_HOME: isolatedConfigHome,
      };
      await expect(
        executeFile("nvim", ["--headless", "+qa!"], { env: environment }),
      ).resolves.toMatchObject({ stderr: "" });
      await expect(
        readlink(
          join(
            runtimeHome,
            "data",
            appName,
            "site",
            "pack",
            "dotkit",
            "opt",
            "pack.nvim",
          ),
        ),
      ).resolves.toBe(resolve(configHome, "nvim-pack/pack.nvim"));
    }),
  );
});

it("refuses to overwrite an occupied Pack bootstrap target", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const target = join(
    runtimeHome,
    "data",
    "nvim",
    "site",
    "pack",
    "dotkit",
    "opt",
    "pack.nvim",
  );
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));
  await mkdir(target, { recursive: true });

  const result = await executeFile("nvim", ["--headless", "+qa!"], {
    env: neovimEnvironment(runtimeHome),
  });

  expect(result.stderr).toContain("Pack bootstrap target is occupied");
  expect((await lstat(target)).isDirectory()).toBe(true);
});

it("loads the active Neovim configuration", async () => {
  const { paletteDirectory, runtimeHome } = await createRuntimeHome();
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));
  await writeFile(
    join(paletteDirectory, "active-theme.json"),
    `${JSON.stringify(theme)}\n`,
  );

  await expect(
    executeFile("nvim", ["--headless", `+lua ${startupAssertions}`, "+qa!"], {
      env: neovimEnvironment(runtimeHome),
    }),
  ).resolves.toMatchObject({ stderr: "" });
});

it("syncs a declared local plugin into the current Neovim app", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const fixture = join(runtimeHome, "fixture.nvim");
  const fixtureModule = join(fixture, "lua", "fixture");
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));
  await mkdir(fixtureModule, { recursive: true });
  await writeFile(join(fixtureModule, "init.lua"), "return { value = 42 }\n");

  const packRoot = resolve(configHome, "nvim-pack", "pack.nvim");
  const target = join(
    runtimeHome,
    "data",
    "nvim",
    "site",
    "pack",
    "local",
    "opt",
    "fixture.nvim",
  );
  const assertions = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    `require('pack').setup({ { path = '${fixture}' } })`,
    "vim.cmd('PackSync fixture.nvim')",
    "vim.cmd.packadd('fixture.nvim')",
    "assert(require('fixture').value == 42)",
  ].join("; ");

  await expect(
    executeFile(
      "nvim",
      ["--headless", "-u", "NONE", `+lua ${assertions}`, "+qa!"],
      { env: packTestEnvironment(runtimeHome) },
    ),
  ).resolves.toMatchObject({ stderr: "" });
  await expect(readlink(target)).resolves.toBe(fixture);
});

it("loads an installed plugin during setup without installing a missing plugin", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const installed = join(runtimeHome, "installed.nvim");
  const missing = join(runtimeHome, "missing.nvim");
  const installedTarget = join(
    runtimeHome,
    "data",
    "nvim",
    "site",
    "pack",
    "local",
    "opt",
    "installed.nvim",
  );
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));
  await mkdir(join(installed, "lua", "installed"), { recursive: true });
  await writeFile(
    join(installed, "lua", "installed", "init.lua"),
    "return { value = 42 }\n",
  );
  await mkdir(resolve(installedTarget, ".."), { recursive: true });
  await import("node:fs/promises").then(({ symlink }) =>
    symlink(installed, installedTarget),
  );

  const packRoot = resolve(configHome, "nvim-pack", "pack.nvim");
  const assertions = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    `require('pack').setup({ { path = '${installed}' }, { path = '${missing}' } })`,
    "assert(require('installed').value == 42)",
  ].join("; ");

  await expect(
    executeFile(
      "nvim",
      ["--headless", "-u", "NONE", `+lua ${assertions}`, "+qa!"],
      { env: packTestEnvironment(runtimeHome) },
    ),
  ).resolves.toMatchObject({ stderr: "" });
  await expect(
    lstat(
      join(
        runtimeHome,
        "data",
        "nvim",
        "site",
        "pack",
        "local",
        "opt",
        "missing.nvim",
      ),
    ),
  ).rejects.toMatchObject({ code: "ENOENT" });
});

it("auto-configures plugins from opts, main, config and dependencies", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const root = join(runtimeHome, "plugins");
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));
  const names = [
    "auto.nvim",
    "explicit.nvim",
    "disabled.nvim",
    "dependency.nvim",
  ];
  await Promise.all(
    names.map((name) =>
      mkdir(join(root, name, "lua", name.replace(".nvim", "")), {
        recursive: true,
      }),
    ),
  );
  await writeFile(
    join(root, "auto.nvim", "lua", "auto", "init.lua"),
    "return { setup = function(o) assert(vim.g.dependency_calls == 1); vim.g.auto_value = o.value end }\n",
  );
  await mkdir(join(root, "explicit.nvim", "lua", "pack_test_explicit"), {
    recursive: true,
  });
  await writeFile(
    join(root, "explicit.nvim", "lua", "pack_test_explicit", "init.lua"),
    "return { setup = function(o) assert(vim.g.dependency_calls == 1); vim.g.explicit_value = o.value end }\n",
  );
  await writeFile(
    join(root, "disabled.nvim", "lua", "disabled", "init.lua"),
    "local M={}; function M.setup() vim.g.disabled_called=true end; return M\n",
  );
  await mkdir(join(root, "dependency.nvim", "lua", "pack_test_dependency"), {
    recursive: true,
  });
  await writeFile(
    join(root, "dependency.nvim", "lua", "pack_test_dependency", "init.lua"),
    "return { setup = function(o) assert(vim.deep_equal(o, {})); vim.g.dependency_calls = (vim.g.dependency_calls or 0) + 1 end }\n",
  );
  const packRoot = resolve(configHome, "nvim-pack", "pack.nvim");
  const paths = names.map((name) => join(root, name));
  const dataRoot = join(
    runtimeHome,
    "data",
    "nvim",
    "site",
    "pack",
    "local",
    "opt",
  );
  await mkdir(dataRoot, { recursive: true });
  const { symlink } = await import("node:fs/promises");
  await Promise.all(
    names.map((name) => symlink(join(root, name), join(dataRoot, name))),
  );
  const assertions = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    `local dep = { path = '${paths[3]}', main = 'pack_test_dependency', opts = {} }`,
    `require('pack').setup({ { path = '${paths[0]}', opts = { value = 7 }, deps = { dep } }, { path = '${paths[1]}', main = 'pack_test_explicit', opts = { value = 8 }, deps = { dep } }, { path = '${paths[2]}', config = false } })`,
    "assert(vim.g.auto_value == 7)",
    "assert(vim.g.explicit_value == 8)",
    "assert(vim.g.disabled_called == nil)",
    "assert(vim.g.dependency_calls == 1)",
    "assert(package.loaded.disabled == nil)",
  ].join("; ");
  await expect(
    executeFile(
      "nvim",
      ["--headless", "-u", "NONE", `+lua ${assertions}`, "+qa!"],
      { env: packTestEnvironment(runtimeHome) },
    ),
  ).resolves.toMatchObject({ stderr: "" });
});

it("syncs a declared Git plugin without using the network", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const fixture = join(runtimeHome, "remote.nvim");
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));
  await mkdir(join(fixture, "lua", "remote"), { recursive: true });
  await writeFile(
    join(fixture, "lua", "remote", "init.lua"),
    "return { value = 42 }\n",
  );
  await executeFile("git", ["init", "-q", fixture]);
  await executeFile("git", ["-C", fixture, "add", "."]);
  await executeFile("git", [
    "-C",
    fixture,
    "-c",
    "user.name=Dotkit Test",
    "-c",
    "user.email=dotkit@example.invalid",
    "commit",
    "-qm",
    "fixture",
  ]);

  const packRoot = resolve(configHome, "nvim-pack", "pack.nvim");
  const source = `file://${fixture}`;
  const assertions = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    `require('pack').setup({ { src = '${source}', name = 'remote.nvim' } })`,
    "vim.cmd('PackSync remote.nvim')",
    "assert(require('remote').value == 42)",
  ].join("; ");

  await expect(
    executeFile(
      "nvim",
      ["--headless", "-u", "NONE", `+lua ${assertions}`, "+qa!"],
      { env: packTestEnvironment(runtimeHome) },
    ),
  ).resolves.toBeDefined();
  const installed = await lstat(
    join(
      runtimeHome,
      "data",
      "nvim",
      "site",
      "pack",
      "core",
      "opt",
      "remote.nvim",
    ),
  );
  expect(installed.isDirectory()).toBe(true);

  await writeFile(
    join(fixture, "lua", "remote", "init.lua"),
    "return { value = 43 }\n",
  );
  await executeFile("git", ["-C", fixture, "add", "."]);
  await executeFile("git", [
    "-C",
    fixture,
    "-c",
    "user.name=Dotkit Test",
    "-c",
    "user.email=dotkit@example.invalid",
    "commit",
    "-qm",
    "update fixture",
  ]);

  const installedModule = join(
    runtimeHome,
    "data",
    "nvim",
    "site",
    "pack",
    "core",
    "opt",
    "remote.nvim",
    "lua",
    "remote",
    "init.lua",
  );
  const updateAssertions = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    `require('pack').setup({ { src = '${source}', name = 'remote.nvim' } })`,
    "vim.cmd('PackSync remote.nvim')",
    `assert(vim.fn.readfile('${installedModule}')[1]:match('43'))`,
  ].join("; ");
  const updateResult = await executeFile(
    "nvim",
    ["--headless", "-u", "NONE", `+lua ${updateAssertions}`, "+qa!"],
    { env: packTestEnvironment(runtimeHome) },
  );
  expect(updateResult.stderr).not.toContain("Error in command line");
  await expect(
    import("node:fs/promises").then(({ readFile }) =>
      readFile(installedModule, "utf8"),
    ),
  ).resolves.toContain("43");
});

it("builds a local plugin only when PackSync creates its link", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const fixture = join(runtimeHome, "fixture.nvim");
  const result = join(runtimeHome, "sync-build.txt");
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));
  await mkdir(fixture, { recursive: true });

  const packRoot = resolve(configHome, "nvim-pack", "pack.nvim");
  const assertions = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    `require('pack').setup({ { path = '${fixture}', build = function() local count = vim.uv.fs_stat('${result}') and tonumber(vim.fn.readfile('${result}')[1]) or 0; vim.fn.writefile({ tostring(count + 1) }, '${result}') end } })`,
    "vim.cmd('PackSync fixture.nvim')",
    "vim.cmd('PackSync fixture.nvim')",
  ].join("; ");

  await expect(
    executeFile(
      "nvim",
      ["--headless", "-u", "NONE", `+lua ${assertions}`, "+qa!"],
      { env: packTestEnvironment(runtimeHome) },
    ),
  ).resolves.toMatchObject({ stderr: "" });
  await expect(
    import("node:fs/promises").then(({ readFile }) => readFile(result, "utf8")),
  ).resolves.toBe("1\n");
});

it("runs a selected plugin build only through PackBuild", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const fixture = join(runtimeHome, "fixture.nvim");
  const result = join(runtimeHome, "build.txt");
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));
  await mkdir(fixture, { recursive: true });

  const packRoot = resolve(configHome, "nvim-pack", "pack.nvim");
  const assertions = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    `require('pack').setup({ { path = '${fixture}', build = function(context) vim.fn.writefile({ context.name, context.path }, '${result}') end } })`,
    "vim.cmd('PackBuild fixture.nvim')",
  ].join("; ");

  await expect(
    executeFile(
      "nvim",
      ["--headless", "-u", "NONE", `+lua ${assertions}`, "+qa!"],
      { env: packTestEnvironment(runtimeHome) },
    ),
  ).resolves.toMatchObject({ stderr: "" });
  await expect(
    import("node:fs/promises").then(({ readFile }) => readFile(result, "utf8")),
  ).resolves.toBe(`fixture.nvim\n${fixture}\n`);
});

it("previews and then removes only stale local links owned by Pack", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const fixture = join(runtimeHome, "fixture.nvim");
  const target = join(
    runtimeHome,
    "data",
    "nvim",
    "site",
    "pack",
    "local",
    "opt",
    "fixture.nvim",
  );
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));
  await mkdir(fixture, { recursive: true });

  const packRoot = resolve(configHome, "nvim-pack", "pack.nvim");
  const install = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    `require('pack').setup({ { path = '${fixture}' } })`,
    "vim.cmd('PackSync')",
  ].join("; ");
  const clean = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    "vim.notify = function() end",
    "require('pack').setup({})",
    "vim.cmd('PackClean')",
    `assert(vim.uv.fs_lstat('${target}'))`,
    "vim.cmd('PackClean!')",
    `assert(not vim.uv.fs_lstat('${target}'))`,
    `assert(vim.uv.fs_stat('${fixture}'))`,
  ].join("; ");

  await executeFile(
    "nvim",
    ["--headless", "-u", "NONE", `+lua ${install}`, "+qa!"],
    { env: packTestEnvironment(runtimeHome) },
  );
  await expect(
    executeFile("nvim", ["--headless", "-u", "NONE", `+lua ${clean}`, "+qa!"], {
      env: packTestEnvironment(runtimeHome),
    }),
  ).resolves.toMatchObject({ stderr: "" });
});

it("reports loaded, missing, and stale local plugin status", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const loaded = join(runtimeHome, "loaded.nvim");
  const missing = join(runtimeHome, "missing.nvim");
  const stale = join(runtimeHome, "stale.nvim");
  const result = join(runtimeHome, "status.json");
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));
  await Promise.all([
    mkdir(join(loaded, "lua", "loaded"), { recursive: true }),
    mkdir(stale, { recursive: true }),
  ]);

  const packRoot = resolve(configHome, "nvim-pack", "pack.nvim");
  const installStale = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    `require('pack').setup({ { path = '${stale}' } })`,
    "require('pack').sync()",
  ].join("; ");
  const inspect = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    `require('pack').setup({ { path = '${loaded}' }, { path = '${missing}' } })`,
    "require('pack').sync({ 'loaded.nvim' })",
    `vim.fn.writefile({ vim.json.encode(require('pack').status()) }, '${result}')`,
  ].join("; ");

  await executeFile(
    "nvim",
    ["--headless", "-u", "NONE", `+lua ${installStale}`, "+qa!"],
    { env: packTestEnvironment(runtimeHome) },
  );
  await executeFile(
    "nvim",
    ["--headless", "-u", "NONE", `+lua ${inspect}`, "+qa!"],
    { env: packTestEnvironment(runtimeHome) },
  );

  const status = await import("node:fs/promises")
    .then(({ readFile }) => readFile(result, "utf8"))
    .then(JSON.parse);
  expect(status).toEqual({
    loaded: [],
    missing: ["missing.nvim"],
    stale: ["stale.nvim"],
    waiting: ["loaded.nvim"],
    conflict: [],
    unknown: [],
  });
});

it("shows categorized plugin state through PackStatus", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const missing = join(runtimeHome, "missing.nvim");
  const result = join(runtimeHome, "status.txt");
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));

  const packRoot = resolve(configHome, "nvim-pack", "pack.nvim");
  const assertions = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    "local messages = {}",
    "vim.notify = function(message) table.insert(messages, message) end",
    `require('pack').setup({ { path = '${missing}' } })`,
    "vim.cmd('PackStatus')",
    `vim.fn.writefile(messages, '${result}')`,
  ].join("; ");

  await expect(
    executeFile(
      "nvim",
      ["--headless", "-u", "NONE", `+lua ${assertions}`, "+qa!"],
      { env: packTestEnvironment(runtimeHome) },
    ),
  ).resolves.toMatchObject({ stderr: "" });
  await expect(
    import("node:fs/promises").then(({ readFile }) => readFile(result, "utf8")),
  ).resolves.toBe("missing  missing.nvim\n");
});

it("syncs a selected plugin together with its dependencies", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const dependency = join(runtimeHome, "dependency.nvim");
  const feature = join(runtimeHome, "feature.nvim");
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));
  await Promise.all([
    mkdir(dependency, { recursive: true }),
    mkdir(feature, { recursive: true }),
  ]);

  const packRoot = resolve(configHome, "nvim-pack", "pack.nvim");
  const assertions = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    `require('pack').setup({ { path = '${feature}', deps = { { path = '${dependency}' } } } })`,
    "require('pack').sync({ 'feature.nvim' })",
  ].join("; ");

  await expect(
    executeFile(
      "nvim",
      ["--headless", "-u", "NONE", `+lua ${assertions}`, "+qa!"],
      { env: packTestEnvironment(runtimeHome) },
    ),
  ).resolves.toMatchObject({ stderr: "" });
  await Promise.all(
    ["dependency.nvim", "feature.nvim"].map((name) =>
      expect(
        readlink(
          join(
            runtimeHome,
            "data",
            "nvim",
            "site",
            "pack",
            "local",
            "opt",
            name,
          ),
        ),
      ).resolves.toBe(join(runtimeHome, name)),
    ),
  );
});

it("loads lazy plugins once after their dependencies", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const dependency = join(runtimeHome, "dependency.nvim");
  const feature = join(runtimeHome, "feature.nvim");
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));
  await Promise.all([
    mkdir(join(dependency, "lua", "dependency"), { recursive: true }),
    mkdir(join(feature, "lua", "feature"), { recursive: true }),
  ]);

  const packRoot = resolve(configHome, "nvim-pack", "pack.nvim");
  const assertions = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    `local Pack = require('pack')`,
    `local specs = { { path = '${feature}', event = 'User DotkitFeature', deps = { { path = '${dependency}' } }, config = function() table.insert(_G.pack_order, 'feature') end }, }`,
    "_G.pack_order = {}",
    "Pack.setup(specs)",
    "Pack.sync()",
    "assert(#_G.pack_order == 0)",
    "vim.api.nvim_exec_autocmds('User', { pattern = 'DotkitFeature' })",
    "assert(vim.deep_equal(_G.pack_order, { 'dependency', 'feature' }))",
    "vim.api.nvim_exec_autocmds('User', { pattern = 'DotkitFeature' })",
    "assert(vim.deep_equal(_G.pack_order, { 'dependency', 'feature' }))",
  ].join("; ");
  await writeFile(
    join(dependency, "plugin", "dependency.lua"),
    "table.insert(_G.pack_order, 'dependency')\n",
  ).catch(async () => {
    await mkdir(join(dependency, "plugin"), { recursive: true });
    await writeFile(
      join(dependency, "plugin", "dependency.lua"),
      "table.insert(_G.pack_order, 'dependency')\n",
    );
  });

  await expect(
    executeFile(
      "nvim",
      ["--headless", "-u", "NONE", `+lua ${assertions}`, "+qa!"],
      { env: packTestEnvironment(runtimeHome) },
    ),
  ).resolves.toMatchObject({ stderr: "" });
});

it("previews and then removes stale Git plugins managed by vim.pack", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const fixture = join(runtimeHome, "remote.nvim");
  const installed = join(
    runtimeHome,
    "data",
    "nvim",
    "site",
    "pack",
    "core",
    "opt",
    "remote.nvim",
  );
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));
  await mkdir(fixture, { recursive: true });
  await writeFile(join(fixture, "README.md"), "fixture\n");
  await executeFile("git", ["init", "-q", fixture]);
  await executeFile("git", ["-C", fixture, "add", "."]);
  await executeFile("git", [
    "-C",
    fixture,
    "-c",
    "user.name=Dotkit Test",
    "-c",
    "user.email=dotkit@example.invalid",
    "commit",
    "-qm",
    "fixture",
  ]);

  const packRoot = resolve(configHome, "nvim-pack", "pack.nvim");
  const install = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    `require('pack').setup({ { src = 'file://${fixture}', name = 'remote.nvim' } })`,
    "require('pack').sync()",
  ].join("; ");
  const clean = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    "vim.notify = function() end",
    "require('pack').setup({})",
    "vim.cmd('PackClean')",
    `assert(vim.uv.fs_stat('${installed}'))`,
    "vim.cmd('PackClean!')",
    `assert(not vim.uv.fs_stat('${installed}'))`,
    `assert(vim.uv.fs_stat('${fixture}'))`,
  ].join("; ");

  await executeFile(
    "nvim",
    ["--headless", "-u", "NONE", `+lua ${install}`, "+qa!"],
    { env: packTestEnvironment(runtimeHome) },
  );
  const result = await executeFile(
    "nvim",
    ["--headless", "-u", "NONE", `+lua ${clean}`, "+qa!"],
    { env: packTestEnvironment(runtimeHome) },
  );
  expect(result.stderr).not.toContain("Error in command line");
});

it("rejects circular plugin dependencies during setup", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const first = join(runtimeHome, "first.nvim");
  const second = join(runtimeHome, "second.nvim");
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));

  const packRoot = resolve(configHome, "nvim-pack", "pack.nvim");
  const assertions = [
    `vim.opt.runtimepath:prepend('${packRoot}')`,
    `local first = { path = '${first}' }`,
    `local second = { path = '${second}', deps = { first } }`,
    "first.deps = { second }",
    "local ok, message = pcall(require('pack').setup, { first })",
    "assert(not ok and message:match('Circular plugin dependency'))",
  ].join("; ");

  await expect(
    executeFile(
      "nvim",
      ["--headless", "-u", "NONE", `+lua ${assertions}`, "+qa!"],
      { env: packTestEnvironment(runtimeHome) },
    ),
  ).resolves.toMatchObject({ stderr: "" });
});

it("presents native Cmdwin as a one-line float while preserving history", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  const initFile = join(runtimeHome, "cmdwin-init.lua");
  const expectFile = join(runtimeHome, "cmdwin.expect");
  const resultFile = join(runtimeHome, "cmdwin.json");
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));

  await writeFile(
    initFile,
    [
      `vim.opt.runtimepath:prepend('${resolve(configHome, "nvim")}')`,
      "vim.fn.histadd(':', 'echo old command')",
      "require('enhance.cmdline').setup()",
      "local presentation",
      `vim.api.nvim_create_autocmd('CmdwinEnter', { once = true, callback = function() local config = vim.api.nvim_win_get_config(0); presentation = { height = config.height, history = vim.api.nvim_buf_get_lines(0, 0, -1, false), relative = config.relative, row = config.row, zindex = config.zindex } end })`,
      `local timer = vim.uv.new_timer(); timer:start(20, 20, vim.schedule_wrap(function() if vim.g.cmdwin_test then timer:stop(); timer:close(); presentation.executed = true; vim.fn.writefile({ vim.json.encode(presentation) }, '${resultFile}'); vim.cmd('qa!') end end))`,
    ].join("\n"),
  );
  await writeFile(
    expectFile,
    String.raw`
      log_user 0
      set timeout 5
      spawn env TERM=xterm-256color nvim -u ${initFile}
      after 200
      send -- ":"
      after 100
      send -- "\006"
      after 100
      send -- "ilet g:cmdwin_test = 1\r"
      expect eof
    `,
  );

  await expect(
    executeFile("/usr/bin/expect", [expectFile], {
      env: neovimEnvironment(runtimeHome),
    }),
  ).resolves.toBeDefined();
  await expect(
    import("node:fs/promises")
      .then(({ readFile }) => readFile(resultFile, "utf8"))
      .then(JSON.parse),
  ).resolves.toEqual({
    executed: true,
    height: 1,
    history: ["echo old command", ""],
    relative: "laststatus",
    row: 1,
    zindex: 201,
  });
}, 10_000);

it("loads the local Pack and Popup plugins from independent runtime roots", async () => {
  const runtimeHome = await mkdtemp(join(tmpdir(), "dotkit-nvim-"));
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));

  const packRoot = resolve(configHome, "nvim-pack");
  const assertions = [
    `vim.opt.runtimepath:prepend('${join(packRoot, "popup.nvim")}')`,
    `vim.opt.runtimepath:prepend('${join(packRoot, "pack.nvim")}')`,
    "assert(type(require('popup').root) == 'function')",
    "assert(type(require('pack').setup) == 'function')",
  ].join("; ");

  await expect(
    executeFile(
      "nvim",
      ["--headless", "-u", "NONE", `+lua ${assertions}`, "+qa!"],
      { env: neovimEnvironment(runtimeHome) },
    ),
  ).resolves.toMatchObject({ stderr: "" });
});

it("updates native colors when Palette atomically publishes a theme", async () => {
  const { paletteDirectory, runtimeHome } = await createRuntimeHome();
  onTestFinished(() => rm(runtimeHome, { force: true, recursive: true }));

  const activeTheme = join(paletteDirectory, "active-theme.json");
  await writeFile(activeTheme, `${JSON.stringify(theme)}\n`);

  const updatedTheme = {
    ...theme,
    id: "dotkit-test-light",
    name: "Dotkit Test Light",
    variant: "light",
    palette: Object.fromEntries(
      Object.keys(theme.palette).map((key, index) => [
        key,
        `#${(0x100001 + index).toString(16)}`,
      ]),
    ),
  };

  const resultFile = join(runtimeHome, "result.json");
  const probe = `vim.defer_fn(function() local result = vim.json.encode({ background = vim.o.background, normal = vim.api.nvim_get_hl(0, { name = 'Normal' }), terminal = vim.g.terminal_color_1 }); vim.fn.writefile({ result }, '${resultFile}'); vim.cmd('qa!') end, 1000)`;

  const neovim = spawn("nvim", ["--headless", `+lua ${probe}`], {
    env: neovimEnvironment(runtimeHome),
  });
  let stderr = "";
  neovim.stderr.setEncoding("utf8");
  neovim.stderr.on("data", (chunk: string) => {
    stderr += chunk;
  });

  await new Promise((resolveDelay) => setTimeout(resolveDelay, 250));
  const temporaryTheme = `${activeTheme}.tmp`;
  await writeFile(temporaryTheme, `${JSON.stringify(updatedTheme)}\n`);
  await rename(temporaryTheme, activeTheme);

  const exitCode = await new Promise<number | null>(
    (resolveExit, rejectExit) => {
      neovim.once("error", rejectExit);
      neovim.once("exit", resolveExit);
    },
  );

  expect({ exitCode, stderr }).toEqual({ exitCode: 0, stderr: "" });
  await expect(
    import("node:fs/promises").then(({ readFile }) =>
      readFile(resultFile, "utf8"),
    ),
  ).resolves.toSatisfy((contents: string) => {
    const result = JSON.parse(contents);
    return (
      result.background === "light" &&
      result.normal.bg === 0x100001 &&
      result.normal.fg === 0x100006 &&
      result.terminal === "#100009"
    );
  });
});
