local api = vim.api
local config = require('plugins.explorer.picker.config')
config.view.preview.enabled = false
local calls = {}
package.loaded['plugins.explorer.picker.search.grep'] = {
  new = function()
    return {
      search = function(query, _, mode, offset)
        calls[#calls + 1] = { query = query, mode = mode, offset = offset }
        local start = offset == 0 and 1 or offset == 7 and 3 or 1
        local items = {}
        for i = start, start + 1 do
          items[#items + 1] =
            { path = '/tmp/' .. i, display = 'x', line = i, col = 0, content = 'x' }
        end
        return {
          status = 'ready',
          items = items,
          total = 4,
          more = offset == 0,
          next_offset = offset == 0 and 7 or 0,
        }
      end,
    }
  end,
}
require('plugins.explorer.picker').open({ mode = 'grep' })
local query = api.nvim_get_current_buf()
local function key(k)
  vim.fn.maparg(k, 'i', false, true).callback()
  assert(api.nvim_get_current_buf() == query, 'Navigation must keep focus on input')
end
api.nvim_buf_set_lines(query, 0, -1, false, { 'x' })
vim.wait(100)
local win
for _, w in ipairs(api.nvim_list_wins()) do
  if vim.bo[api.nvim_win_get_buf(w)].filetype == 'file-picker' then
    win = w
  end
end
assert(api.nvim_win_get_config(win).focusable == false)
for _ = 1, 3 do
  key('<C-n>')
end
assert(calls[#calls].offset == 7, 'Grep must request fff next offset')
local count = #calls
for _ = 1, 3 do
  key('<C-p>')
end
assert(#calls == count, 'Returning should reuse the cached page')
key('<Esc>')
print('PASS Grep page offsets')
vim.cmd('qa!')
