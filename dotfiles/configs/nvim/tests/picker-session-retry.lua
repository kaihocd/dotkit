local api = vim.api
local config = require('plugins.explorer.picker.config')
config.view.preview.enabled = false
config.search.scan_poll_ms = 5
local blocked, requested = false, false
package.loaded['plugins.explorer.picker.search.grep'] = {
  new = function()
    return {
      search = function(_, _, _, offset)
        if blocked and offset == 0 then
          requested = true
          return { status = 'indexing', items = {}, total = 0 }
        end
        local items = {}
        for i = 1, 2 do
          items[i] = {
            path = '/tmp/retry-' .. offset,
            display = 'retry',
            line = offset + i + 1,
            col = 0,
            content = 'hit-' .. (offset + i),
          }
        end
        return {
          status = 'ready',
          items = items,
          total = 10,
          more = offset < 4,
          next_offset = offset + 1,
        }
      end,
    }
  end,
}
local picker = require('plugins.explorer.picker')
local function key(k)
  vim.fn.maparg(k, 'i', false, true).callback()
end
local function results()
  for _, win in ipairs(api.nvim_list_wins()) do
    if vim.bo[api.nvim_win_get_buf(win)].filetype == 'file-picker' then
      return win
    end
  end
end
picker.open({ mode = 'grep', get_icon = function() end })
local query = api.nvim_get_current_buf()
for _ = 1, 8 do
  key('<C-n>')
end -- page 4; page 0 is evicted
blocked = true
for _ = 1, 7 do
  key('<C-p>')
end
assert(requested, 'Returning to evicted page must hit indexing')
blocked = false
local win = results()
assert(
  vim.wait(1000, function()
    local row = api.nvim_win_get_cursor(win)[1]
    return api
      .nvim_buf_get_lines(api.nvim_win_get_buf(win), row - 1, row, false)[1]
      :find('hit-2', 1, true) ~= nil
  end),
  'Grep retry must select the last hit'
)
key('<Esc>')
assert(vim.wait(1000, function()
  return not api.nvim_buf_is_valid(query)
end))
package.loaded['plugins.explorer.picker.search.files'] = {
  new = function()
    return {
      search = function(_, size, page)
        if blocked then
          return { status = 'indexing', items = {}, total = 0 }
        end
        local items = {}
        for i = page * size + 1, (page + 1) * size do
          items[#items + 1] = { path = '/tmp/r-' .. i, display = 'r-' .. i }
        end
        return { status = 'ready', items = items, total = 1000 }
      end,
    }
  end,
}
vim.o.lines = 30
picker.open({ get_icon = function() end })
query = api.nvim_get_current_buf()
win = results()
for _ = 1, api.nvim_win_get_height(win) + 3 do
  key('<C-n>')
end
local row = api.nvim_win_get_cursor(win)[1]
local selected = api.nvim_buf_get_lines(api.nvim_win_get_buf(win), row - 1, row, false)[1]
blocked = true
vim.o.lines = 40
api.nvim_exec_autocmds('VimResized', {})
blocked = false
assert(
  vim.wait(1000, function()
    row = api.nvim_win_get_cursor(win)[1]
    return api.nvim_buf_get_lines(api.nvim_win_get_buf(win), row - 1, row, false)[1] == selected
  end),
  'Files resize retry must preserve logical selection'
)
key('<Esc>')
assert(vim.wait(1000, function()
  return not api.nvim_buf_is_valid(query)
end))
print('PASS session pagination retries')
