vim.opt.runtimepath:prepend(vim.fn.getcwd())
require('picker').setup()
local syntax = require('picker.picker.window.syntax')
assert(#syntax.highlights('/file.unknown_picker_extension', 'text') == 0)
local get_parser = vim.treesitter.get_string_parser
local function unavailable()
  error('missing parser')
end
vim.treesitter.get_string_parser = unavailable
assert(#syntax.highlights('/file.lua', 'local value = 1') == 0)
vim.treesitter.get_string_parser = get_parser
-- Neovim ships its Lua parser/query; exercise actual capture offsets, not a mock.
local before = #vim.api.nvim_list_bufs()
local text, highlights = require('picker.picker.window.format').match({
  path = '/file.lua',
  display = 'file.lua',
  line = 7,
  col = 0,
  content = 'local value = "你好"',
  content_matches = { { 0, 5 } },
})
assert(text == ':7:1  local value = "你好"')
local keyword, match = false, false
for _, h in ipairs(highlights) do
  if h.group:find('^@keyword') and h.first == 6 and h.last == 11 then
    keyword = true
    assert(h.priority < 200)
  end
  if h.group == 'Search' then
    match = true
    assert(h.first == 6 and h.last == 11 and h.priority == 200)
  end
  assert(h.last <= #text)
end
assert(keyword and match)
assert(#vim.api.nvim_list_bufs() == before, 'snippet parsing must not create buffers')
local destroyed = false
local query = vim.treesitter.query.get
local function tracked_parser(...)
  local parser = get_parser(...)
  local destroy = parser.destroy
  parser.destroy = function(self)
    destroyed = true
    destroy(self)
  end
  vim.treesitter.query.get = function()
    error('broken query')
  end
  return parser
end
vim.treesitter.get_string_parser = tracked_parser
assert(#syntax.highlights('/file.lua', 'local value = 1') == 0 and destroyed)
vim.treesitter.get_string_parser = get_parser
vim.treesitter.query.get = query
print(
  'PASS snippet real Lua captures, prefix offsets, match priority and optional parser/query cleanup'
)
