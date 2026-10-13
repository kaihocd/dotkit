vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
require('picker').setup()
local List = require('picker.select.list')
local Panel = require('picker.select.panel')
local Window = require('picker.select.window')
local config = require('picker.select.config')

local settings = require('picker.config')
settings.setup({
  select = {
    view = { prefix = { text = ' Custom ' } },
    keymaps = { i = { ['<C-l>'] = false }, n = { ['<C-l>'] = false } },
  },
})
local configured = assert(Panel.new({ 'one' }, {}, function() end))
---@diagnostic disable-next-line: invisible
assert(configured.window._config.prefix.text == ' Custom ')
settings.setup()
---@diagnostic disable-next-line: invisible
assert(configured.window._config.prefix.text == ' Custom ')
configured:close()
vim.wait(10)

local list = List.new({ false, true })
local text = list:texts()
text[1] = 'changed'
assert(list:texts()[1] == '1. false')
local item, index = list:choice()
assert(item == false and index == 1)
print('PASS SelectList copied texts and false-valued choice')

local texts = {}
for i = 1, 40 do
  texts[i] = 'candidate ' .. i
end
local window = Window.new('Prompt', texts, 30, assert(config.options()))
window:open()
local pane = assert(window:pane('list'))
local function viewport()
  return vim.api.nvim_win_call(assert(window:pane('list')).win, vim.fn.winsaveview)
end
local before = viewport()
window:show_detail(string.rep('long text ', 100))
local detail = assert(window:pane('detail'))
assert(detail.buf ~= pane.buf)
assert(window:pane('list') == nil)
assert(window:detail_active() and vim.wo[detail.win].wrap)
assert(vim.api.nvim_buf_is_valid(pane.buf))
window:scroll_detail(1)
window:leave_detail()
assert(not window:detail_active() and not vim.wo[window:pane('list').win].wrap)
assert(viewport().topline == before.topline)
window:show_detail('another detail')
window:render({ 'replacement' }, 1)
assert(not window:detail_active() and viewport().topline == 1)
window:close()
window:close()
print('PASS independent SelectWindow detail viewport and replacement')

local completed = 0
local panel = assert(Panel.new({ 'first', 'second' }, {}, function()
  completed = completed + 1
end))
panel:open()
panel:open()
local actions = panel:commands()
actions.cancel()
actions.cancel()
assert(vim.wait(1000, function()
  return completed == 1
end))
actions.move(1)
assert(actions.choice() == nil)
assert(#vim.api.nvim_list_wins() == 1)

local reopened
local original = assert(Panel.new({ 'old' }, {}, function()
  reopened = assert(Panel.new({ 'new' }, {}, function() end))
  reopened:open()
end))
original:open()
original:close()
assert(vim.wait(1000, function()
  return reopened ~= nil
end))
assert(reopened.window:focused(true))
reopened:close()
assert(vim.wait(1000, function()
  return #vim.api.nvim_list_wins() == 1
end))
print('PASS SelectPanel completion once, closed Actions and callback reopen')

local original_create = vim.api.nvim_create_autocmd
local ids = {}
local registrations = 0
local function create(event, options)
  registrations = registrations + 1
  if registrations == 2 then
    error('test: Select partial event registration')
  end
  local id = original_create(event, options)
  ids[#ids + 1] = id
  return id
end
rawset(vim.api, 'nvim_create_autocmd', create)
local failures = 0
local failing = assert(Panel.new({ 'a' }, {}, function()
  failures = failures + 1
end))
failing:open()
rawset(vim.api, 'nvim_create_autocmd', original_create)
assert(vim.wait(1000, function()
  return failures == 1
end))
for _, id in ipairs(ids) do
  assert(#vim.api.nvim_get_autocmds({ id = id }) == 0)
end
assert(#vim.api.nvim_list_wins() == 1)
print('PASS SelectBindings partial registration rollback')

local dormant_calls = 0
local dormant = assert(Panel.new({ 'never opened' }, {}, function()
  dormant_calls = dormant_calls + 1
end))
dormant:close()
dormant:open()
assert(vim.wait(1000, function()
  return dormant_calls == 1
end))
assert(#vim.api.nvim_list_wins() == 1)

local raw = assert(Panel.new({ string.rep('Alpha', 30) }, {}, function() end))
raw:open()
local input = assert(raw.window:pane('input'))
vim.api.nvim_buf_set_lines(input.buf, 0, -1, false, { 'a' })
raw:refresh()
raw:toggle_detail()
assert(raw.window:detail_active())
vim.api.nvim_buf_set_lines(input.buf, 0, -1, false, { 'A' })
raw:refresh()
assert(not raw.window:detail_active(), 'raw-only input changes must exit detail')
raw:close()
assert(vim.wait(1000, function()
  return #vim.api.nvim_list_wins() == 1
end))
print('PASS close before open and raw-only query changes')

local Bindings = require('picker.select.bindings')
local editor = Bindings.new(require('picker.config').resolve('select').keymaps)
local unopened = Window.new('Pending', { 'a' }, 1, assert(config.options()))
local function ignore() end
editor:attach(unopened.popup, {
  confirm = ignore,
  cancel = ignore,
  toggle_detail = ignore,
  move = ignore,
  page = ignore,
  choice = function()
    return nil, nil
  end,
}, {
  active = function()
    return true
  end,
  click = ignore,
  refresh = ignore,
  focus = ignore,
})
editor:detach()
editor:detach()
unopened:open()
for _, event in ipairs(vim.api.nvim_get_autocmds({})) do
  assert(event.desc ~= 'Update Select list from input', 'late open registered input events')
  assert(
    event.desc ~= 'Close Select when focus leaves its panes',
    'late open registered focus events'
  )
end
unopened:close()
print('PASS detached Bindings ignores late open')
