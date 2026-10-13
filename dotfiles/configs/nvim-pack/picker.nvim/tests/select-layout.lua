vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
require('picker').setup()
local Window = require('picker.select.window')
local config = require('picker.select.config')
local popup = require('popup')
local api = vim.api
local function buffers()
  local result = {}
  for _, buf in ipairs(api.nvim_list_bufs()) do
    result[buf] = true
  end
  return result
end
local before = buffers()
local function clean()
  assert(#api.nvim_list_wins() == 1)
  for _, buf in ipairs(api.nvim_list_bufs()) do
    assert(before[buf], 'leaked buffer')
  end
end
for _, compose in ipairs({ popup.row, popup.col }) do
  local window = Window.new(
    'Prompt',
    { 'one', 'two' },
    2,
    assert(config.options({
      min_items = 10,
      max_items = 10,
      layout = function(panes, context)
        assert(context.width > 0 and context.height > 0)
        return compose({
          children = {
            popup.col({ children = { panes.input, panes.list } }),
            panes.detail,
          },
        })
      end,
    }))
  )
  window:open()
  local list, detail = assert(window:pane('list')), assert(window:pane('detail'))
  local lines = api.nvim_buf_get_lines(list.buf, 0, -1, false)
  local cursor = api.nvim_win_get_cursor(list.win)
  window:show_detail('first\nsecond')
  assert(vim.deep_equal(api.nvim_buf_get_lines(detail.buf, 0, -1, false), { 'first', 'second' }))
  window:scroll_detail(1)
  local input = assert(window:pane('input'))
  api.nvim_buf_set_lines(input.buf, 0, -1, false, { 'query' })
  local columns = vim.o.columns
  vim.o.columns = columns + 10
  window:resize()
  assert(window:query() == 'query' and window:detail_active())
  assert(window:pane('input').buf == input.buf)
  vim.o.columns = columns
  window:resize()
  window:leave_detail()
  assert(vim.deep_equal(api.nvim_buf_get_lines(list.buf, 0, -1, false), lines))
  assert(vim.deep_equal(api.nvim_win_get_cursor(list.win), cursor))
  window:close()
  clean()
end
print('PASS Select nested horizontal/vertical layout and independent multiline detail')
local invalid = {
  function(p)
    return { type = 'col', children = { p.input, p.list, hidden = p.list } }
  end,
  function(p)
    return { type = 'col', children = { p.input, p.list, { type = 'row', children = {} } } }
  end,
  function(p)
    p.detail.buf = 0
    return popup.col({ children = { p.input, p.list } })
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
    p.list = popup.pane({ id = 'list' })
    return popup.col({ children = { p.input, p.list } })
  end,
  function(p)
    local tree = popup.col({ children = { p.input, p.list } })
    tree.children[3] = tree
    return tree
  end,
}
for _, callback in ipairs(invalid) do
  assert(
    not pcall(Window.new, 'Prompt', { 'one' }, 1, assert(config.options({ layout = callback })))
  )
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
local ok = pcall(Window.new, 'Prompt', { 'one' }, 1, assert(config.options()))
rawset(api, 'nvim_create_buf', create)
assert(not ok)
clean()
print('PASS Select layout rejection and incremental allocation rollback')

local Panel = require('picker.select.panel')
local evaluations, completed = 0, 0
local panel = assert(Panel.new({ 'one', 'two' }, {
  view = {
    layout = function(p)
      evaluations = evaluations + 1
      if evaluations > 1 then
        error('resize callback failed')
      end
      return popup.col({ children = { p.input, p.list } })
    end,
  },
}, function(item, index)
  assert(item == nil and index == nil)
  completed = completed + 1
end))
panel:open()
api.nvim_exec_autocmds('VimResized', {})
assert(vim.wait(1000, function()
  return completed == 1
end))
api.nvim_exec_autocmds('VimResized', {})
assert(evaluations == 2 and completed == 1, 'resize listener survived close')
clean()
print('PASS Select resize callback failure cancels once and detaches listener')

local default = Window.new('Prompt', { 'one', 'two' }, 2, assert(config.options()))
default:open()
local list = assert(default:pane('list'))
local lines = api.nvim_buf_get_lines(list.buf, 0, -1, false)
default:show_detail(string.rep('wrapped text ', 40))
default:resize()
assert(default:detail_active() and default:pane('detail').buf ~= list.buf)
assert(vim.deep_equal(api.nvim_buf_get_lines(list.buf, 0, -1, false), lines))
default:leave_detail()
assert(not default:pane('detail'))
default:close()
clean()

local height = vim.o.lines
local small_completed = 0
local small = assert(Panel.new({ 'one' }, {}, function()
  small_completed = small_completed + 1
end))
small:open()
vim.o.lines = 5
api.nvim_exec_autocmds('VimResized', {})
assert(vim.wait(1000, function()
  return small_completed == 1
end))
vim.o.lines = height
clean()
print('PASS default detail resize and small-screen cancellation release resources')

for _, role in ipairs({ 'root', 'input', 'list', 'preview', 'detail' }) do
  local resolved, problem = config.options({ [role] = {} })
  assert(not resolved and problem and problem:find('no longer supported', 1, true))
end
local failed_detail = 0
local failing = assert(Panel.new({ string.rep('long', 100) }, {}, function()
  failed_detail = failed_detail + 1
end))
failing:open()
local render = failing.window.popup.render
failing.window.popup.render = function()
  error('detail mount failed')
end
failing:toggle_detail()
failing.window.popup.render = render
assert(vim.wait(1000, function()
  return failed_detail == 1
end))
clean()
print('PASS removed Select fields rejected and detail mount failure cancels safely')

local states = {}
local long = string.rep('native wrap ', 50)
local transition = assert(Panel.new({ 'short', long }, {
  view = {
    layout = function(p, context)
      states[#states + 1] = context.detail
      return popup.col({ children = { p.input, context.detail and p.detail or p.list } })
    end,
  },
}, function() end))
transition:open()
local input = assert(transition.window:pane('input'))
local original = assert(transition.window:pane('list'))
local geometry = api.nvim_win_get_config(original.win)
transition:toggle_detail()
assert(not transition.window:detail_active() and #states == 1)
transition:move(1)
transition:toggle_detail()
local detail = assert(transition.window:pane('detail'))
assert(not transition.window:pane('list'))
local now = api.nvim_win_get_config(detail.win)
assert(now.width == geometry.width and now.height == geometry.height)
assert(vim.deep_equal(now.row, geometry.row) and vim.deep_equal(now.col, geometry.col))
assert(transition.window:pane('input').win == input.win)
assert(api.nvim_buf_line_count(detail.buf) == 1)
assert(api.nvim_buf_get_lines(detail.buf, 0, -1, false)[1] == long)
transition:toggle_detail()
assert(vim.deep_equal(states, { false, true, false }))
assert(transition.window:pane('list').buf == original.buf)
assert(api.nvim_win_get_cursor(transition.window:pane('list').win)[1] == 3)
transition:close()
assert(vim.wait(1000, function()
  return #api.nvim_list_wins() == 1
end))
clean()
print('PASS clipped-only detail replaces list in place with native wrap and documented context')

-- Exercise the public formatting → list projection → action → detail chain.
local original_text = string.rep('wrapped ', 60) .. '\n\nsecond line\n'
local expected_lines = vim.split(original_text, '\n', { plain = true })
local public_completed = false
require('picker').select({ { label = original_text } }, {
  format_item = function(item)
    return item.label
  end,
  keymaps = { i = {
    ['<F9>'] = function(actions)
      actions.toggle_detail()
    end,
  } },
}, function()
  public_completed = true
end)
local input_buf = api.nvim_get_current_buf()
local mapping = vim.fn.maparg('<F9>', 'i', false, true)
assert(type(mapping.callback) == 'function')
mapping.callback()
local detail_win
for _, win in ipairs(api.nvim_list_wins()) do
  if vim.bo[api.nvim_win_get_buf(win)].filetype == 'picker-select-detail' then
    detail_win = win
  end
end
assert(detail_win and vim.wo[detail_win].wrap)
assert(vim.wo[detail_win].linebreak, 'detail must prefer native word-boundary wrapping')
local detail_buf = api.nvim_win_get_buf(detail_win)
assert(vim.deep_equal(api.nvim_buf_get_lines(detail_buf, 0, -1, false), expected_lines))
api.nvim_exec_autocmds('VimResized', {})
assert(vim.deep_equal(api.nvim_buf_get_lines(detail_buf, 0, -1, false), expected_lines))
assert(api.nvim_get_current_buf() == input_buf)
vim.fn.maparg('<C-c>', 'i', false, true).callback()
assert(vim.wait(1000, function()
  return public_completed
end))
clean()
print('PASS public Select preserves formatter newlines and native soft-wrap across resize')

for _, action in ipairs({ 'filter', 'move' }) do
  local exit_evaluations, cancellations = 0, 0
  local failure = assert(Panel.new({ string.rep('long ', 100), 'other' }, {
    view = {
      layout = function(p, context)
        exit_evaluations = exit_evaluations + 1
        if exit_evaluations == 3 then
          error('exit detail failed')
        end
        return popup.col({ children = { p.input, context.detail and p.detail or p.list } })
      end,
    },
  }, function()
    cancellations = cancellations + 1
  end))
  failure:open()
  failure:toggle_detail()
  assert(failure.window:detail_active())
  if action == 'filter' then
    api.nvim_buf_set_lines(failure.window:pane('input').buf, 0, -1, false, { 'long' })
    failure:refresh()
  else
    failure:move(1)
    assert(failure.list:current_index() == 1, 'failed exit must not continue movement')
  end
  assert(vim.wait(1000, function()
    return cancellations == 1
  end))
  clean()
end
print('PASS filter/move layout failures cancel once without continuing actions')
