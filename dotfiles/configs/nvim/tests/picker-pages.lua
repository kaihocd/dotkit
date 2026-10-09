local api = vim.api
local config = require('plugins.explorer.picker.config')
vim.o.lines = 30
vim.o.columns = 100
local total = 1000
config.view.preview.enabled = false
local calls = {}
package.loaded['plugins.explorer.picker.search.files'] = {
  new = function()
    return {
      search = function(query, size, page)
        calls[#calls + 1] = { query, page }
        local items = {}
        for i = page * size + 1, math.min(total, (page + 1) * size) do
          items[#items + 1] = { path = '/tmp/page-' .. i, display = 'page-' .. i }
        end
        return { status = 'ready', items = items, total = total }
      end,
    }
  end,
}
require('plugins.explorer.picker').open({ get_icon = function() end })
local query = api.nvim_get_current_buf()
local function key(lhs)
  vim.fn.maparg(lhs, 'i', false, true).callback()
end
local results
for _, win in ipairs(api.nvim_list_wins()) do
  if vim.bo[api.nvim_win_get_buf(win)].filetype == 'file-picker' then
    results = win
  end
end
local size = api.nvim_win_get_height(results)
key('<Tab>')
for _ = 2, size do
  key('<C-n>')
end
assert(calls[#calls][2] == 1, 'Navigation must request the next backend page')
local count = #calls
key('<C-p>')
assert(#calls == count, 'Previous page must come from the cache')
for _ = 1, size * 3 + 1 do
  key('<C-n>')
end
assert(calls[#calls][2] == 4)
for _ = 1, size * 4 do
  key('<C-p>')
end
assert(calls[#calls][2] == 0 and #calls > count, 'Evicted pages must be reloaded')
key('<C-n>')
local selected = api.nvim_buf_get_lines(api.nvim_win_get_buf(results), 1, 2, false)[1]
vim.o.lines = 40
api.nvim_exec_autocmds('VimResized', {})
local row = api.nvim_win_get_cursor(results)[1]
assert(
  api.nvim_buf_get_lines(api.nvim_win_get_buf(results), row - 1, row, false)[1] == selected,
  'Resize preserves the selected file'
)
local function selected_line()
  local cursor = api.nvim_win_get_cursor(results)[1]
  return api.nvim_buf_get_lines(api.nvim_win_get_buf(results), cursor - 1, cursor, false)[1]
end
local before_toggle = selected_line()
local expanded_height = api.nvim_win_get_height(results)
key('<C-o>')
local compact_height = api.nvim_win_get_height(results)
assert(compact_height < expanded_height, 'Stacked Preview reduces result height')
assert(
  api.nvim_buf_line_count(api.nvim_win_get_buf(results)) == compact_height,
  'Toggle must resize Files pages'
)
assert(selected_line() == before_toggle, 'Opening Preview preserves selection')
key('<C-o>')
assert(
  api.nvim_buf_line_count(api.nvim_win_get_buf(results)) == expanded_height,
  'Closing Preview restores page size'
)
assert(selected_line() == before_toggle, 'Closing Preview preserves selection')
api.nvim_buf_set_lines(query, 0, -1, false, { 'new query' })
key('<C-n>')
assert(calls[#calls][1] == 'new query' and calls[#calls][2] == 0)
key('<Esc>')
vim.wait(1000, function()
  return not api.nvim_buf_is_valid(query)
end)
print('PASS Picker Files pages')
vim.cmd('qa!')
