vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
require('picker').setup()
local Session = require('picker.picker.panel')
local before = #vim.api.nvim_get_autocmds({ event = 'ColorScheme' })
vim.api.nvim_set_hl(0, 'Added', { fg = 0xffffff })
vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 0 })
local calls = 0
local session = Session.new({
  search = function()
    calls = calls + 1
    return {
      status = 'ready',
      total = 1,
      items = {
        { path = '/fixture.lua', display = 'fixture.lua', git_status = 'staged_new' },
      },
    }
  end,
}, function() end, { icon = false })
session:open()
local pane = assert(session.window:pane('list'))
local tick = vim.api.nvim_buf_get_changedtick(pane.buf)
local input = vim.api.nvim_get_current_win()
local searches = calls
assert(#vim.api.nvim_get_autocmds({ event = 'ColorScheme' }) == before + 1)
local staged_group = 'PickerSignStaged_Added_600'
assert(vim.api.nvim_get_hl(0, { name = staged_group, link = false }).fg == 0x999999)
vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 0xffffff })
vim.api.nvim_exec_autocmds('ColorScheme', {})
assert(vim.api.nvim_get_hl(0, { name = staged_group, link = false }).fg == 0xffffff)
assert(calls == searches and vim.api.nvim_buf_get_changedtick(pane.buf) == tick)
assert(vim.api.nvim_get_current_win() == input and session.selection:current_index() == 1)
session:close()
assert(#vim.api.nvim_get_autocmds({ event = 'ColorScheme' }) == before)
vim.api.nvim_exec_autocmds('ColorScheme', {})
assert(calls == searches)
assert(vim.wait(2000, function()
  return not vim.api.nvim_buf_is_valid(pane.buf)
end))
print('PASS live theme repaint without search/content/focus changes and close removes listener')
