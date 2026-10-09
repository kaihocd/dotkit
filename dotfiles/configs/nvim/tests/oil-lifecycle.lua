local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root .. '/dotfiles/configs/nvim')
vim.opt.runtimepath:prepend(root .. '/dotfiles/configs/nvim-pack/popup.nvim')
local api = vim.api
local Adapter = require('plugins.explorer.oil.adapter')
local popup = require('popup')
-- Only Oil's directory loading is stubbed; windows, groups and events are real.
package.loaded.oil = {
  get_current_dir = function()
    return vim.fn.getcwd()
  end,
  open = function(_, _, callback)
    callback()
  end,
}
popup.group('oil-lifecycle-test', {})
local function adapter(group)
  return Adapter.new({
    min_pane_size = 3,
    border = 'solid',
    group = group or 'oil-lifecycle-test',
    geometry = function()
      return { width = 30, height = 8, row = 1, col = 1 }
    end,
    oil_title = function()
      return { title = 'Oil' }
    end,
    preview_title = function()
      return { title = 'Preview' }
    end,
    keymaps = {},
    oil_win_options = {},
    preview_win_options = {},
  })
end
local origin = api.nvim_get_current_win()
local source = api.nvim_get_current_buf()
local subject = adapter()
local Panel = require('plugins.explorer.oil.panel')
local failing = Panel.new(subject.config, function() end)
failing.popup:on('open', function()
  error('injected open failure')
end)
local ok, err = pcall(failing.open, failing)
assert(not ok and tostring(err):find('injected open failure', 1, true))
assert(subject.active == nil, 'failed open leaves active session')
assert(#api.nvim_list_wins() == 1, 'failed open leaves windows')
assert(failing.phase == 'closed')
subject:toggle()
assert(subject.active and subject.active.win)
api.nvim_exec_autocmds('BufEnter', { buffer = source })
subject:close()
vim.wait(30)
assert(subject.active == nil and #api.nvim_list_wins() == 1)
assert(api.nvim_buf_is_valid(source))
subject:toggle()
api.nvim_win_close(subject.active.win, true)
vim.wait(30)
assert(subject.active == nil and #api.nvim_list_wins() == 1)
-- Preview owns its scratch buffer but must retain borrowed file buffers.
local Preview = require('plugins.explorer.oil.preview')
local hidden = 0
local owner = Panel.new(subject.config, function() end)
local preview = Preview.new(function(buf)
  return owner:create_popup('preview', buf, {})
end, function()
  hidden = hidden + 1
end)
preview:open()
preview:render({ row = 1, col = 1, width = 20, height = 5 })
local scratch = preview.empty
api.nvim_win_close(preview.popup:pane('preview').win, true)
assert(hidden == 1 and not preview:is_visible())
assert(api.nvim_buf_is_valid(scratch), 'hide discarded reusable scratch buffer')
preview:open()
preview:render({ row = 1, col = 1, width = 20, height = 5 })
assert(preview.empty == scratch)
preview:close()
preview:close()
assert(not api.nvim_buf_is_valid(scratch))
owner:close()
local missing = adapter('oil-missing-group')
assert(not pcall(missing.toggle, missing))
assert(missing.active == nil and #api.nvim_list_wins() == 1)
for _, event in ipairs(api.nvim_get_autocmds({})) do
  assert(event.group_name ~= 'DotkitOilSession', 'session autocmd leaked')
end
api.nvim_set_current_win(origin)
local cmdwin_done = false
api.nvim_create_autocmd('CmdwinEnter', {
  once = true,
  callback = function()
    local before = #api.nvim_list_wins()
    local current = api.nvim_get_current_win()
    subject:toggle()
    assert(subject.active == nil)
    assert(#api.nvim_list_wins() == before and api.nvim_get_current_win() == current)
    cmdwin_done = true
    vim.schedule(function()
      vim.cmd.quit()
    end)
  end,
})
api.nvim_feedkeys('q:', 'xt', false)
assert(cmdwin_done, 'real Cmdwin was not entered')
print('PASS Oil failed-open rollback, retry, external close, stale events and Cmdwin guard')
