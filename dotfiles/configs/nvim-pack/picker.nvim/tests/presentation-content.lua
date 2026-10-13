vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local content = require('picker.content')
require('picker').setup()
local presentation = require('picker.picker.presentation')
local function resolve_presentation(options, mode)
  local settings =
    require('picker.config').resolve('picker', { view = { presentation = options } }, mode)
  return presentation.resolve(settings.view.presentation, mode)
end
local custom = function()
  return { content = { { 'custom' } } }
end
for _, mode in ipairs({ 'files', 'grep' }) do
  local defaults = resolve_presentation(nil, mode)
  assert(defaults.prefix.text == (mode == 'files' and ' Files ' or ' Grep '))
  assert(defaults.row.match == 'Search' and defaults.row.current == 'CursorLine')
  local resolved = resolve_presentation({ format = custom, prefix = { margin = { 2, 3 } } }, mode)
  assert(resolved.format == custom and resolved.prefix.margin[2] == 3)
end
assert(not pcall(resolve_presentation, { prefix = { files = {} } }))
assert(not pcall(resolve_presentation, { format_item = custom }))
local legacy = vim.json.decode('{"text":"legacy"}')
assert(not pcall(content.project, legacy))
local text, ranges =
  content.project({ content = { { '中', 'Title' }, { 'a' }, { '文', 'Search' } } })
assert(text == '中a文' and ranges[2].first == 4 and ranges[2].last == 7)
require('picker').setup()
local view = {
  icon = false,
  presentation = {
    row = { match = 'IncSearch', current = 'Visual' },
  },
}
local window = require('picker.picker.window').new(
  require('picker.picker.options').resolve({ view = view }).view
)
window:open()
window:render({ { path = '/a', display = 'a', match_ranges = { { 0, 1 } } } }, 1)
local pane = assert(window:pane('list'))
local namespaces = vim.api.nvim_get_namespaces()
local marks =
  vim.api.nvim_buf_get_extmarks(pane.buf, namespaces.PickerList, 0, -1, { details = true })
assert(marks[1][4].hl_group == 'IncSearch')
local current =
  vim.api.nvim_buf_get_extmarks(pane.buf, namespaces.PickerListCurrent, 0, -1, { details = true })
assert(current[1][4].hl_group == 'Visual' and current[1][4].hl_eol)
local input = assert(window:pane('input'))
local prefix = vim.api.nvim_buf_get_extmarks(
  input.buf,
  namespaces.PickerInput,
  0,
  -1,
  { details = true }
)[1][4].virt_text
assert(prefix)
assert(prefix[2][1] == ' Files ' and prefix[3][1] == ' ')
assert(window:query() == '')
window:select(nil)
assert(#vim.api.nvim_buf_get_extmarks(pane.buf, namespaces.PickerListCurrent, 0, -1, {}) == 0)
window:close()
print('PASS presentation defaults, single overrides, segments, current/match and prefix gap')
