vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local layout = require('picker.picker.window.layout')
local options = require('picker.picker.options')
local popup = require('popup')
vim.o.columns = 200
vim.o.lines = 60
local buffers = {}
for i = 1, 3 do
  buffers[i] = vim.api.nvim_create_buf(false, true)
end
local function build(value)
  local resolved = options.resolve({ view = { layout = value } })
  return layout.build(resolved.view, buffers, true)
end
local root = build(nil)
assert(root.width == 140 and root.height == 42)
root = build({ width_ratio = 0.8, height_ratio = 0.5 })
assert(root.width == 160 and root.height == 30 and root.col == 20 and root.row == 15)
local calls = 0
local function arrange(panes, size)
  calls = calls + 1
  assert(size.width == 160 and size.height == 30)
  return popup.row({
    children = { popup.col({ children = { panes.input, panes.list } }), panes.preview },
  })
end
build({ width_ratio = 0.8, height_ratio = 0.5, build = arrange })
assert(calls == 1)
root = build({ width_ratio = 0.01, height_ratio = 0.01 })
assert(root.width == 20 and root.height == 6)
root = build({ width_ratio = 1, height_ratio = 1 })
assert(root.width == 200 and root.height == 60)
vim.o.columns = 100
vim.o.lines = 40
root = build({ width_ratio = 0.8, height_ratio = 0.5 })
assert(root.width == 80 and root.height == 20)
for _, key in ipairs({ 'width_ratio', 'height_ratio' }) do
  for _, value in ipairs({ 0, -1, 1.1, math.huge, 0 / 0, '0.7', false }) do
    assert(not pcall(build, { [key] = value }), key .. ' accepted invalid ratio')
  end
end
assert(not pcall(build, { build = true }))
assert(not pcall(build, { width = 80 }))
for _, buf in ipairs(buffers) do
  vim.api.nvim_buf_delete(buf, { force = true })
end
print('PASS Picker layout ratios, builder budget, resize and validation')
