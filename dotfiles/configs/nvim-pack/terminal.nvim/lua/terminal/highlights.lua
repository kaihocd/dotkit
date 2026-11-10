local M = {}

-- Define default highlight groups for terminal panes.
local function set_defaults()
  vim.api.nvim_set_hl(0, 'TerminalList', { link = 'Pmenu', default = true })
  vim.api.nvim_set_hl(0, 'TerminalListActive', { link = 'Function', default = true })
  vim.api.nvim_set_hl(0, 'TerminalListNormal', { link = 'Pmenu', default = true })
  vim.api.nvim_set_hl(0, 'TerminalTerm', { link = 'NormalFloat', default = true })
  vim.api.nvim_set_hl(0, 'TerminalHelp', { link = 'Pmenu', default = true })
  vim.api.nvim_set_hl(0, 'TerminalListOk', { link = 'DiagnosticOk', default = true })
  vim.api.nvim_set_hl(0, 'TerminalListFailed', { link = 'DiagnosticError', default = true })
end

-- Register terminal highlights and keep them stable across colorscheme changes.
function M.setup()
  set_defaults()

  vim.api.nvim_create_autocmd('ColorScheme', {
    callback = set_defaults,
  })
end

-- Apply window-local highlight mappings to terminal panes.
---@param list_win? integer
---@param term_win? integer
---@param help_win? integer
function M.apply_winhl(list_win, term_win, help_win)
  if list_win and vim.api.nvim_win_is_valid(list_win) then
    vim.api.nvim_set_option_value(
      'winhl',
      'Normal:TerminalList,NormalFloat:TerminalList,EndOfBuffer:TerminalList,FloatBorder:TerminalList',
      { win = list_win }
    )
    vim.api.nvim_set_option_value('cursorline', false, { win = list_win })
  end

  if term_win and vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_set_option_value('winhl', 'Normal:TerminalTerm', { win = term_win })
  end

  if help_win and vim.api.nvim_win_is_valid(help_win) then
    vim.api.nvim_set_option_value(
      'winhl',
      'Normal:TerminalHelp,NormalFloat:TerminalHelp,EndOfBuffer:TerminalHelp,FloatBorder:TerminalHelp',
      { win = help_win }
    )
  end
end

return M
