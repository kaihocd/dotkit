local M = {}

function M.config()
  -- Match the old default without restoring its global state framework.
  local format_on_save = false
  require('conform').setup({
    notify_on_error = true,
    notify_no_formatters = true,
    formatters_by_ft = {
      javascript = { 'prettierd' },
      typescript = { 'prettierd' },
      javascriptreact = { 'prettierd' },
      typescriptreact = { 'prettierd' },
      vue = { 'prettierd' },
      json = { 'prettierd' },
      css = { 'prettierd' },
      less = { 'prettierd' },
      html = { 'prettierd' },
      yaml = { 'prettierd' },
      markdown = { 'prettierd' },
      lua = { 'stylua' },
      zsh = { 'shfmt' },
      bash = { 'shfmt' },
      sh = { 'shfmt' },
    },
    format_on_save = function(bufnr)
      if format_on_save and vim.bo[bufnr].buftype == '' then
        return { timeout_ms = 1000 }
      end
    end,
  })

  vim.keymap.set({ 'n', 'x' }, '<leader>lf', function()
    require('conform').format({ timeout_ms = 1000, async = false })
  end, { desc = 'Format buffer or selection' })

  vim.api.nvim_create_user_command('ToggleFormatOnSave', function()
    format_on_save = not format_on_save
    vim.notify('Format on Save: ' .. (format_on_save and 'Enabled' or 'Disabled'))
  end, { desc = 'Toggle format on save for this session' })
end

return M
