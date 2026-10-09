local M = {}

local parsers = {
  'bash',
  'javascript',
  'json',
  'lua',
  'luadoc',
  'markdown',
  'markdown_inline',
  'query',
  'tsx',
  'typescript',
  'vim',
  'vimdoc',
  'yaml',
}

local function highlight(buf)
  if not vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].buftype ~= '' then
    return
  end
  local language = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
  if language and vim.tbl_contains(parsers, language) then
    -- Keep native syntax while a parser is unavailable or still installing.
    pcall(vim.treesitter.start, buf, language)
  end
end

function M.config()
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('ConfigTreesitter', { clear = true }),
    callback = function(event)
      highlight(event.buf)
    end,
  })

  -- Install missing parsers only; use :TSUpdate after upgrading the plugin.
  require('nvim-treesitter').install(parsers):await(function()
    vim.schedule(function()
      -- Also attach buffers opened before installation finished.
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        highlight(buf)
      end
    end)
  end)
end

return M
