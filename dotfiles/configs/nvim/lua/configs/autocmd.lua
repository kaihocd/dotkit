local function augroup(name)
  return vim.api.nvim_create_augroup('Configs' .. name, {
    clear = true,
  })
end

vim.api.nvim_create_autocmd('TextYankPost', {
  group = augroup('HighlightYank'),
  desc = 'Highlight yanked text',
  callback = function()
    vim.highlight.on_yank()
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('ConfigsQuickfix', { clear = true }),
  pattern = 'qf',
  callback = function()
    vim.opt_local.winfixheight = false
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  group = augroup('CloseWithQ'),
  pattern = { 'qf', 'help', 'checkhealth', 'lspinfo' },
  callback = function(event)
    vim.bo[event.buf].buflisted = false

    vim.keymap.set('n', 'q', '<Cmd>close<CR>', {
      buffer = event.buf,
      silent = true,
      desc = 'Close window',
    })
  end,
})
