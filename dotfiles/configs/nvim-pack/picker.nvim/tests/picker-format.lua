vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local format = require('picker.picker.window.format')
local path = '目录/文件.lua'
local text, highlights = format.file({
  path = '/' .. path,
  display = path,
  match_ranges = { { 0, #path } },
}, 'λ', 'Special')
assert(text == 'λ  文件.lua 目录')
local matches = {}
for _, highlight in ipairs(highlights) do
  if highlight.priority == 200 then
    matches[#matches + 1] = text:sub(highlight.first + 1, highlight.last)
  end
end
assert(vim.deep_equal(matches, { '文件.lua', '目录' }))
local plain = format.file({ path = '/a.lua', display = 'a.lua' })
assert(plain == 'a.lua')
local clean = format.file({ path = '/d/a\tb.lua', display = 'd/a\tb.lua' })
assert(clean == 'a b.lua d')
print('PASS basename-first Unicode byte mapping, separator exclusion and normalization')

local list_view = require('picker.picker.window.list')
local built = list_view.build({
  mode = 'grep',
  width = 80,
  entries = {
    { path = '/a.lua', display = 'a.lua', line = 1, content = 'one' },
    { path = '/a.lua', display = 'a.lua', line = 2, content = 'two' },
    { path = '/b.lua', display = 'b.lua', line = 3, content = 'three' },
  },
  icon = function()
    return nil
  end,
  empty_text = 'No Item',
})
assert(#built.rows == 5)
assert(built.entry_rows[1] == 2 and built.entry_rows[2] == 3 and built.entry_rows[3] == 5)
assert(built.row_entries[1] == nil and built.row_entries[2] == 1 and built.row_entries[3] == 2)
print('PASS list view builds selectable grep rows separately from headings')

local list_items = require('picker.picker.window.row')
local custom_row = list_items.item(
  { path = '/a.lua', display = 'a.lua', git_status = 'modified' },
  'files',
  80,
  function()
    return '★', 'Title'
  end,
  function(entry, context)
    assert(entry.path == '/a.lua')
    assert(context.mode == 'files')
    assert(context.icon == '★' and context.git_status == 'modified')
    return { content = { { 'custom item' } } }
  end
)
assert(require('picker.content').project(custom_row) == 'custom item')
assert(
  not pcall(
    list_items.item,
    { path = '/a.lua', display = 'a.lua' },
    'files',
    80,
    function() end,
    function()
      return { highlight = 'Title' }
    end
  )
)
print('PASS list item formatter receives isolated context and validates rows')

local View = require('picker.picker.window')
local view = View.new({
  icon = function()
    return 'λ', 'Special'
  end,
  layout = function(panes)
    panes.list.size = { fixed = 20 }
    return require('popup').row({ children = { panes.input, panes.list } })
  end,
})
view:open()
local long = '目录/文件文件文件文件文件文件.lua'
view:render({ { path = '/' .. long, display = long, match_ranges = { { 0, #long } } } }, 1)
local pane = assert(view:pane('list'))
local line = vim.api.nvim_buf_get_lines(pane.buf, 0, 1, false)[1]
local ellipsis = assert(line:find('…', 1, true)) - 1
local namespaces = vim.api.nvim_get_namespaces()
local ns = namespaces.PickerList
local marks = vim.api.nvim_buf_get_extmarks(pane.buf, ns, 0, -1, { details = true })
assert(#marks >= 2)
for _, mark in ipairs(marks) do
  assert(mark[4].end_col <= ellipsis, 'highlight must not include clipped suffix or ellipsis')
  for _, boundary in ipairs({ mark[3], mark[4].end_col }) do
    local byte = line:byte(boundary + 1)
    assert(not byte or byte < 128 or byte >= 192, 'highlight split a UTF-8 character')
  end
end
view:render({ { path = '/plain', display = 'plain' } }, 1)
marks = vim.api.nvim_buf_get_extmarks(pane.buf, ns, 0, -1, { details = true })
assert(#marks == 1, 'old directory and match highlights leaked into next render')
view:close()
print('PASS clipped Unicode highlights exclude ellipsis and stale ranges are cleared')
