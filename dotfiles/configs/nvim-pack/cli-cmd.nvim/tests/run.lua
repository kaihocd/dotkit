-- Run from the repository root: nvim --clean --headless -i NONE -l dotfiles/configs/nvim-pack/cli-cmd.nvim/tests/run.lua
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(root)
_G.cli_cmd_test = dofile(root .. '/tests/support.lua')
local count, failures, skipped = 0, 0, 0

---Every file under `tests/` is a test module except the runner and the shared
---fixtures, so a tool's tests live beside the tool instead of in one flat list.
local function is_test_file(path)
  local name = vim.fn.fnamemodify(path, ':t')
  return name ~= 'run.lua' and name ~= 'support.lua'
end

---A test whose subject is not on this machine says so instead of passing silently:
---"155 passed" must not be able to hide "and two of them did nothing".
local SKIP = {}

---`xpcall` would turn a raised skip into a traceback string, so the sentinel passes
---through untouched and everything else is traced as usual.
local function traced(error_object)
  if type(error_object) == 'table' and error_object == SKIP then
    return error_object
  end
  return debug.traceback(error_object)
end

---Each test reports how long it took: a test that failed after 0.004s and one that
---failed after 15s of waiting are different bugs, and a slow test is worth seeing
---before it turns into a flake.
local function test(name, fn)
  count = count + 1
  local started = vim.uv.hrtime()
  local ok, err = xpcall(fn, traced)
  local elapsed = (vim.uv.hrtime() - started) / 1e9
  if ok then
    print(('PASS %s (%.3fs)'):format(name, elapsed))
    return
  end
  if err == SKIP then
    skipped = skipped + 1
    print(('SKIP %s (%.3fs)'):format(name, elapsed))
    return
  end
  failures = failures + 1
  print(('FAIL %s (%.3fs)'):format(name, elapsed))
  print(err)
end

local paths = vim.fn.glob(root .. '/tests/**/*.lua', false, true)
table.sort(paths)
for _, path in ipairs(paths) do
  if is_test_file(path) then
    local relative = path:sub(#root + 2)
    ---A callable table, not a function: a test file gets `test` and `test.skip`, and
    ---Lua functions cannot carry fields.
    ---@type fun(name: string, fn: function), {skip: fun(reason: string)}
    local file_test = setmetatable({}, {
      __call = function(_, name, fn)
        test(relative .. ': ' .. name, fn)
      end,
    })
    ---Call from inside a test when what it needs is not on this machine.
    ---@param reason string e.g. "brew is not installed"
    file_test.skip = function(reason)
      print('  skipping: ' .. reason)
      error(SKIP)
    end
    dofile(path)(file_test)
  end
end
print(('%d tests, %d failures, %d skipped'):format(count, failures, skipped))
vim.cmd(failures == 0 and 'qa!' or 'cquit 1')
