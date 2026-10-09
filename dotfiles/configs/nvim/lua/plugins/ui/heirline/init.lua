local M = {}

function M.config()
  local heirline = require('heirline')
  local utils = require('heirline.utils')
  local palette_group = vim.api.nvim_create_augroup('DotkitHeirlinePalette', { clear = true })

  local initialized = false
  local function load_palette()
    local semantic = require('palette.highlights').current()
    if not semantic then
      return
    end
    utils.on_colorscheme(semantic)
    if not initialized then
      heirline.setup({
        tabline = require('plugins.ui.heirline.tabline'),
        statusline = require('plugins.ui.heirline.statusline'),
      })
      vim.opt.showtabline = 2
      initialized = true
    end
    vim.cmd('redrawtabline')
    vim.cmd('redrawstatus')
  end

  load_palette()
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = palette_group,
    pattern = '*',
    callback = load_palette,
  })

  local group = vim.api.nvim_create_augroup('DotkitStatusline', { clear = true })
  vim.api.nvim_create_autocmd({
    'ModeChanged',
    'DiagnosticChanged',
    'LspAttach',
    'LspDetach',
    'RecordingEnter',
    'RecordingLeave',
  }, {
    group = group,
    callback = function()
      vim.schedule(function()
        vim.cmd('redrawstatus')
      end)
    end,
  })

  vim.api.nvim_create_autocmd({
    'WinEnter',
    'BufEnter',
    'BufFilePost',
    'DirChanged',
    'FileType',
    'BufModifiedSet',
    'BufWritePost',
    'TabEnter',
  }, {
    group = group,
    callback = function()
      vim.cmd('redrawtabline')
    end,
  })
  vim.api.nvim_create_autocmd('OptionSet', {
    group = group,
    pattern = { 'readonly', 'modifiable' },
    callback = function()
      vim.cmd('redrawtabline')
    end,
  })
end

return M
