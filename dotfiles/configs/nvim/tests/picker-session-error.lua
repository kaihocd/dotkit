local api = vim.api
local windows = #api.nvim_list_wins()
local closed = 0
local content = require('plugins.explorer.picker.preview.content')
local new = content.new
local function tracked_reader(...)
  local reader = new(...)
  local close = reader.close
  reader.close = function()
    closed = closed + 1
    close()
  end
  return reader
end
content.new = tracked_reader
package.loaded['plugins.explorer.picker.search.files'] = {
  new = function()
    return {
      search = function()
        return {
          status = 'ready',
          total = 1,
          items = { { path = '/tmp/error-test', display = 'error-test' } },
        }
      end,
    }
  end,
}
local error_message
local notify = vim.notify
local function capture_error(message)
  error_message = message
end
vim.notify = capture_error
local picker = require('plugins.explorer.picker')
picker.open({
  get_icon = function()
    error('icon failure')
  end,
})
assert(vim.wait(1000, function()
  return #api.nvim_list_wins() == windows
end))
assert(error_message:find('icon failure', 1, true))
assert(closed == 1, 'Render failure must close the reader')
picker.open({ get_icon = function() end })
local query = api.nvim_get_current_buf()
assert(vim.bo[query].filetype == 'file-picker-input', 'Picker must reopen after failure')
vim.fn.maparg('<Esc>', 'i', false, true).callback()
assert(vim.wait(1000, function()
  return not api.nvim_buf_is_valid(query)
end))
vim.notify = notify
content.new = new
print('PASS session render failure cleanup and reopen')
