vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
require('picker').setup()
local Window = require('picker.picker.window')
local function create_window(view, mode)
  local options = require('picker.picker.options').resolve({ view = view, mode = mode })
  return Window.new(options.view, mode)
end
local popup = require('popup')
local api = vim.api
local before = {}
for _, buf in ipairs(api.nvim_list_bufs()) do
  before[buf] = true
end
local function clean()
  assert(#api.nvim_list_wins() == 1)
  for _, buf in ipairs(api.nvim_list_bufs()) do
    assert(before[buf], 'layout leaked buffer')
  end
end
local invalid = {
  function(p)
    return { type = 'col', children = { p.input, p.list, hidden = p.list } }
  end,
  function(p)
    return { type = 'col', children = { p.input, p.list, { type = 'row', children = {} } } }
  end,
  function()
    return nil
  end,
  function()
    return false
  end,
  function()
    error('callback failed')
  end,
  function(p)
    return p.input
  end,
  function(p)
    return popup.col({ children = { p.input, p.list, p.list } })
  end,
  function(p)
    p.list.buf = 0
    return popup.col({ children = { p.input, p.list } })
  end,
  function(p)
    p.list.id = 'other'
    return popup.col({ children = { p.input, p.list } })
  end,
  function(p)
    p.list = popup.pane({ id = 'list', buf = p.list.buf })
    return popup.col({ children = { p.input, p.list } })
  end,
  function(p)
    local tree = popup.col({ children = { p.input, p.list } })
    tree.children[3] = tree
    return tree
  end,
}
for _, callback in ipairs(invalid) do
  assert(not pcall(create_window, { layout = callback }))
  clean()
end
local create = api.nvim_create_buf
local calls = 0
rawset(api, 'nvim_create_buf', function(...)
  calls = calls + 1
  if calls == 2 then
    error('allocation failed')
  end
  return create(...)
end)
local ok = pcall(create_window, {})
rawset(api, 'nvim_create_buf', create)
assert(not ok)
clean()
print('PASS Picker rejects invalid layout, replacement identity and allocation failures')
for _, compose in ipairs({ popup.row, popup.col }) do
  local evaluations = 0
  local window = create_window({
    layout = function(panes, context)
      evaluations = evaluations + 1
      assert(context.width > 0 and context.height > 0)
      local main = popup.col({ children = { panes.input, panes.list } })
      return panes.preview and compose({ children = { main, panes.preview } }) or main
    end,
  })
  window:open()
  local input = assert(window:pane('input'))
  api.nvim_buf_set_lines(input.buf, 0, -1, false, { 'query' })
  window:toggle_preview()
  assert(window:pane('preview'))
  window:resize()
  assert(evaluations == 3)
  assert(window:pane('input').buf == input.buf and window:query() == 'query')
  window:toggle_preview()
  assert(not window:pane('preview'))
  window:close()
  clean()
end
print('PASS Picker horizontal/vertical layout rebuild retains query and owned buffers')
