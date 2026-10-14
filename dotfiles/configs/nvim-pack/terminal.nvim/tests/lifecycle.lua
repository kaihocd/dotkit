local root = vim.fn.getcwd() .. '/dotfiles/configs/nvim-pack/'
vim.opt.rtp:append(root .. 'popup.nvim')
vim.opt.rtp:append(root .. 'terminal.nvim')
local state = require('terminal.state')
local terminal = require('terminal')
local jobs = {}
local ok, err = xpcall(function()
  local config = require('terminal.config')
  vim.opt.rtp:append(vim.fn.getcwd() .. '/dotfiles/configs/nvim')
  local popup_config = require('plugins.ui.popup')
  popup_config.config()
  local options =
    { shell = { '/bin/sh' }, auto_insert = false, group = popup_config.EXCLUSIVE_GROUP }
  terminal.setup(options)
  options.shell[1] = '/missing-shell'
  assert(config.get().shell[1] == '/bin/sh')
  assert(config.get().group == 'exclusive')
  terminal.open()
  terminal.close()
  terminal.shutdown()
  local snapshot = config.get()
  snapshot.shell[1] = '/another-missing-shell'
  assert(config.get().shell[1] == '/bin/sh')
  assert(config.defaults == nil and config.options == nil)
  assert(not pcall(terminal.setup, 'invalid'))
  assert(config.get().shell[1] == '/bin/sh')
  terminal.setup({ shell = { '/bin/sh' }, auto_insert = false })
  for _, border in ipairs({ 'invalid', {}, { 'ab' }, { 'x', 'x', 'x' } }) do
    assert(not pcall(terminal.setup, { border = border }))
  end
  local keymaps = require('terminal.keymaps')
  local setup_term = keymaps.setup_term
  local failed_buf
  ---@diagnostic disable-next-line: duplicate-set-field -- Scoped fault injection, restored below.
  keymaps.setup_term = function(buf)
    failed_buf = buf
    error('injected binding failure')
  end
  local created, failure = pcall(terminal.new)
  keymaps.setup_term = setup_term
  assert(not created and tostring(failure):find('injected binding failure', 1, true))
  assert(failed_buf and not vim.api.nvim_buf_is_valid(failed_buf))
  assert(state.count() == 0)

  local open_win = vim.api.nvim_open_win
  local allocations = 0
  ---@diagnostic disable-next-line: duplicate-set-field -- Scoped fault injection, restored below.
  vim.api.nvim_open_win = function(...)
    allocations = allocations + 1
    if allocations == 2 then
      error('injected window failure')
    end
    return open_win(...)
  end
  local opened, open_error = pcall(terminal.open)
  vim.api.nvim_open_win = open_win
  assert(not opened and tostring(open_error):find('injected window failure', 1, true))
  assert(allocations == 2 and state.popup == nil and state.settings == nil)
  assert(#vim.api.nvim_list_wins() == 1)
  terminal.open()
  terminal.hide()
  vim.api.nvim_buf_delete(state.help_buf, { force = true })
  terminal.open()
  assert(vim.api.nvim_buf_is_valid(state.help_buf))
  local first = state.current()
  assert(first)
  jobs[#jobs + 1] = first.job_id
  assert(vim.fn.jobwait({ first.job_id }, 0)[1] == -1)
  local win = assert(terminal.term_win())
  local cfg = vim.api.nvim_win_get_config(win)
  assert(cfg.title and #cfg.title > 0)
  local old_settings = state.settings
  terminal.setup({
    shell = { '/bin/sh' },
    auto_insert = false,
    term_title = ' Updated ',
    help_text = { ' Updated help ' },
    keymaps = { term = { ['Z'] = false, ['Y'] = false } },
  })
  assert(not pcall(terminal.setup, { width_ratio = -1 }))
  assert(require('terminal.config').get().term_title == ' Updated ')
  terminal.hide()
  assert(not require('terminal.float').is_open())
  assert(vim.fn.jobwait({ first.job_id }, 0)[1] == -1)
  terminal.open()
  assert(vim.api.nvim_win_get_buf(assert(terminal.term_win())) == first.buf)
  assert(state.settings == old_settings)
  assert(state.settings.term_title == ' Terminal ')
  terminal.close()
  terminal.open()
  assert(state.settings.term_title == ' Updated ')
  assert(vim.api.nvim_buf_get_lines(state.help_buf, 0, -1, false)[1] == ' Updated help ')
  local function has_key(key)
    for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(first.buf, 'n')) do
      if mapping.lhs == key then
        return true
      end
    end
    return false
  end
  assert(has_key('Z'))
  local user_mapping = function() end
  vim.keymap.set('n', 'Y', user_mapping, { buffer = first.buf })
  terminal.setup({ shell = { '/bin/sh' }, auto_insert = false })
  terminal.close()
  terminal.open()
  assert(not has_key('Z'))
  assert(has_key('Y'), 'rebuilding must preserve a user replacement for a removed key')
  assert(vim.fn.jobwait({ first.job_id }, 0)[1] == -1)
  terminal.new({ name = 'second' })
  local second = assert(state.current())
  jobs[#jobs + 1] = second.job_id
  terminal.select(1)
  assert(vim.api.nvim_win_get_buf(assert(terminal.term_win())) == first.buf)
  terminal.focus_left()
  terminal.delete_under_cursor()
  assert(state.count() == 1 and state.current() == second)
  vim.fn.chansend(second.job_id, 'exit\n')
  assert(vim.wait(3000, function()
    return state.count() == 0
  end))
  assert(not require('terminal.float').is_open())
  terminal.open()
  jobs[#jobs + 1] = assert(state.current()).job_id
  terminal.shutdown()
  assert(state.count() == 0)
  for _, job in ipairs(jobs) do
    assert(vim.fn.jobwait({ job }, 1000)[1] ~= -1)
  end
end, debug.traceback)
terminal.shutdown()
assert(ok, err)
print('Terminal lifecycle checks passed')
vim.cmd('qa!')
