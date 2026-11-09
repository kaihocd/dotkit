-- Run from the repository root: nvim --clean --headless -i NONE -l dotfiles/configs/nvim-pack/cli.nvim/tests/run.lua
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(root)
_G.cli_test = dofile(root .. '/tests/support.lua')
local count, failures = 0, 0
local function test(name, fn)
  count = count + 1
  local ok, err = xpcall(fn, debug.traceback)
  print((ok and 'PASS ' or 'FAIL ') .. name)
  if not ok then
    failures = failures + 1
    print(err)
  end
end
for _, path in ipairs(vim.fn.glob(root .. '/tests/test_*.lua', false, true)) do
  dofile(path)(test)
end
print(('%d tests, %d failures'):format(count, failures))
vim.cmd(failures == 0 and 'qa!' or 'cquit 1')
