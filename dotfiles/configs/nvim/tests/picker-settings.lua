local api = vim.api
local config = require('plugins.explorer.picker.config')
local picker = require('plugins.explorer.picker')
local windows = #api.nvim_list_wins()
for _, case in ipairs({
  { config.view, 'width', 0, 'view.width' },
  { config.search.grep, 'page_size', -1, 'search.grep.page_size' },
  { config.preview.content, 'max_bytes', 1.5, 'preview.content.max_bytes' },
  { config.preview.content, 'max_prefetch', -1, 'preview.content.max_prefetch' },
}) do
  local old = case[1][case[2]]
  case[1][case[2]] = case[3]
  local ok, err = pcall(picker.open)
  case[1][case[2]] = old
  assert(not ok and tostring(err):find(case[4], 1, true))
  assert(#api.nvim_list_wins() == windows, 'Validation must precede window creation')
end
local received
package.loaded['plugins.explorer.picker.search.grep'] = {
  new = function(_, _, options)
    received = options
    return {
      search = function()
        return { status = 'ready', items = {}, total = 0 }
      end,
    }
  end,
}
picker.open({ mode = 'grep' })
local query = api.nvim_get_current_buf()
local old = config.search.grep.max_file_size
config.search.grep.max_file_size = old + 1
assert(received.max_file_size == old, 'Active session must own a configuration snapshot')
config.search.grep.max_file_size = old
vim.fn.maparg('<Esc>', 'i', false, true).callback()
assert(vim.wait(1000, function()
  return not api.nvim_buf_is_valid(query)
end))
print('PASS settings validation and snapshot')
