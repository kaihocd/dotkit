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
