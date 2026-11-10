-- Run from the repository root: nvim --clean --headless -i NONE -l dotfiles/configs/nvim-pack/cli-cmd.nvim/tests/run.lua
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(root)
_G.cli_cmd_test = dofile(root .. '/tests/support.lua')
local count, failures = 0, 0

---Every file under `tests/` is a test module except the runner and the shared
---fixtures, so a tool's tests live beside the tool instead of in one flat list.
local function is_test_file(path)
  local name = vim.fn.fnamemodify(path, ':t')
  return name ~= 'run.lua' and name ~= 'support.lua'
end

---Each test reports how long it took: a test that failed after 0.004s and one that
---failed after 15s of waiting are different bugs, and a slow test is worth seeing
---before it turns into a flake.
local function test(name, fn)
  count = count + 1
  local started = vim.uv.hrtime()
  local ok, err = xpcall(fn, debug.traceback)
  local elapsed = (vim.uv.hrtime() - started) / 1e9
  print(('%s %s (%.3fs)'):format(ok and 'PASS' or 'FAIL', name, elapsed))
  if not ok then
    failures = failures + 1
    print(err)
  end
end

local paths = vim.fn.glob(root .. '/tests/**/*.lua', false, true)
table.sort(paths)
for _, path in ipairs(paths) do
  if is_test_file(path) then
    local relative = path:sub(#root + 2)
    local file_test = function(name, fn)
      test(relative .. ': ' .. name, fn)
    end
    dofile(path)(file_test)
  end
end
print(('%d tests, %d failures'):format(count, failures))
vim.cmd(failures == 0 and 'qa!' or 'cquit 1')
