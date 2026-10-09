local api = vim.api
local config = require('plugins.explorer.picker.config')
local picker = require('plugins.explorer.picker')
config.view.preview.enabled = false
local origin = api.nvim_get_current_win()
local baseline = #api.nvim_list_wins()
local starts = {}
for _, mode in ipairs({ 'files', 'grep' }) do
  package.loaded['plugins.explorer.picker.search.' .. mode] = {
    new = function()
      starts[#starts + 1] = mode
      assert(#api.nvim_list_wins() == baseline, 'Replacement must wait for old window cleanup')
      return {
        search = function()
          return { status = 'ready', items = {}, total = 0 }
        end,
      }
    end,
  }
end
picker.open()
local old_query = api.nvim_get_current_buf()
local cancel = vim.fn.maparg('<Esc>', 'i', false, true).callback
picker.open({ mode = 'grep' })
picker.open({ mode = 'files' })
assert(#starts == 1, 'Open during close must not start another instance')
assert(vim.wait(1000, function()
  return #starts == 2
end))
assert(starts[2] == 'files', 'Latest pending request wins')
assert(not api.nvim_buf_is_valid(old_query))
local query = api.nvim_get_current_buf()
assert(vim.bo[query].filetype == 'file-picker-input')
cancel()
assert(api.nvim_buf_is_valid(query), 'Stale old callbacks must not close the replacement')

local width = config.view.width
config.view.width = 0
assert(not pcall(picker.open))
config.view.width = width
assert(api.nvim_buf_is_valid(query), 'Invalid settings must not replace the active instance')
vim.fn.maparg('<Esc>', 'i', false, true).callback()
assert(vim.wait(1000, function()
  return not api.nvim_buf_is_valid(query)
end))
assert(#api.nvim_list_wins() == baseline and api.nvim_get_current_win() == origin)
print('PASS Picker active instance replacement')
