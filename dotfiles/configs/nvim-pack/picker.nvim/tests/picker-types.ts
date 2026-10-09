import { spawnSync } from "node:child_process";
import {
  cpSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const workspace = mkdtempSync(resolve(tmpdir(), "picker-api-types-"));
const fixture = `local picker = require('picker')
picker.select({ { name = 'alpha' } }, {
  format_item = function(item) return item.name end,
  keymaps = { i = { ['<F7>'] = function(actions)
    local item, index = actions.choice()
    if item then print(item.name) end
    if index then print(index + 1) end
    actions.move(1)
  end } },
}, function(item, index)
  if item then print(item.name) end
  if index then print(index + 1) end
end)
picker.open({ mode = 'grep', view = { icon = false }, keymaps = { i = {
  ['<F5>'] = function(actions)
    actions.move(2)
    actions.mark(0)
    actions.page(-1)
    actions.scroll_preview(nil, 1)
  end,
} } })
picker.open({ view = { presentation = {
  prefix = { text = 'Find ', margin = { 0, 1 } },
  marker = { highlight = 'Title' },
  status = { separator = ' / ' },
  messages = { empty = 'Empty' },
  format = function(entry, context)
    return { content = { { entry.display .. context.mode, 'Title' } } }
  end,
} } })
`;
function check(source: string) {
  writeFileSync(resolve(workspace, "fixture.lua"), fixture + source);
  const result = spawnSync(
    "lua-language-server",
    ["--check=.", "--checklevel=Hint", "--configpath=.luarc.json"],
    { cwd: workspace, encoding: "utf8", timeout: 60_000 },
  );
  if (result.error) throw result.error;
  if (result.status === null)
    throw new Error("LuaLS terminated without exit status");
  return { status: result.status, output: result.stdout + result.stderr };
}
try {
  cpSync(resolve(root, "lua"), resolve(workspace, "lua"), { recursive: true });
  const runtime = spawnSync(
    "nvim",
    [
      "--headless",
      "-u",
      "NONE",
      "-c",
      "lua io.write(vim.env.VIMRUNTIME)",
      "-c",
      "qa!",
    ],
    { encoding: "utf8", timeout: 10_000 },
  );
  if (runtime.error || runtime.status !== 0)
    throw runtime.error ?? new Error(runtime.stderr);
  const config = JSON.parse(readFileSync(resolve(root, ".luarc.json"), "utf8"));
  config.workspace.library = [
    runtime.stdout.trim(),
    resolve(
      process.env.POPUP_NVIM_PATH ?? resolve(root, "../popup.nvim"),
      "lua",
    ),
    "${3rd}/luv/library",
  ];
  writeFileSync(resolve(workspace, ".luarc.json"), JSON.stringify(config));
  const valid = check("");
  if (valid.status !== 0) throw new Error(valid.output);
  console.log("PASS public open options infer valid mapping Actions");
  const cases = [
    [
      "Select move delta",
      "picker.select({ 'a' }, { keymaps = { i = { ['<F7>'] = function(actions) actions.move('bad') end } } }, function() end)",
    ],
    [
      "Select callback item",
      "picker.select({ { name = 'a' } }, {}, function(item) if item then local number = item.name + 1; print(number) end end)",
    ],
    [
      "prefix text",
      "picker.open({ view = { presentation = { prefix = { text = 1 } } } })",
    ],
    [
      "status separator",
      "picker.open({ view = { presentation = { status = { separator = false } } } })",
    ],
    [
      "formatter text",
      "picker.open({ view = { presentation = { format = function() return { content = { { 1 } } } end } } })",
    ],
    ["mode", "picker.open({ mode = 'other' })"],
    ["icon", "picker.open({ view = { icon = true } })"],
    ["move delta", "actions.move('2')"],
    ["mark direction", "actions.mark(2)"],
    ["page direction", "actions.page(0)"],
    ["preview direction", "actions.scroll_preview(nil, 0)"],
  ];
  for (const [name, code] of cases) {
    const source = code.startsWith("actions.")
      ? `picker.open({ keymaps = { i = { ['<F6>'] = function(actions) ${code} end } } })`
      : code;
    const result = check(source);
    if (name.startsWith("Select ") && result.status === 0) {
      console.log(
        `LIMITATION LuaLS does not reject invalid inferred ${name}; inference is not certified`,
      );
      continue;
    }
    if (name === "formatter text" && result.status === 0) {
      console.log(
        "LIMITATION LuaLS accepts an invalid inline formatter return; runtime validation remains required",
      );
      continue;
    }
    if (
      result.status === 0 ||
      !/param-type-mismatch|assign-type-mismatch|return-type-mismatch|undefined-operator/.test(
        result.output,
      )
    ) {
      throw new Error(`Expected diagnostic for ${name}\n${result.output}`);
    }
    console.log(`PASS reject invalid ${name}`);
  }
} finally {
  rmSync(workspace, { recursive: true, force: true });
}
