local M = {}

local function with_float_options(open)
  return function()
    open({
      max_width = math.max(1, math.floor(vim.o.columns * 0.65)),
      max_height = math.max(1, math.floor(vim.o.lines * 0.35)),
    })
  end
end

local function setup_interactions()
  local group = vim.api.nvim_create_augroup('LspInteractions', { clear = true })
  local highlight_method = 'textDocument/documentHighlight'

  vim.api.nvim_create_autocmd('LspAttach', {
    group = group,
    callback = function(event)
      local function map(mode, key, open, description)
        vim.keymap.set(mode, key, with_float_options(open), {
          buffer = event.buf,
          desc = description,
        })
      end

      map('n', 'K', vim.lsp.buf.hover, 'Hover')
      map('n', '<C-w>d', vim.diagnostic.open_float, 'Line diagnostics')
      map('i', '<C-s>', vim.lsp.buf.signature_help, 'Signature help')
    end,
  })

  vim.api.nvim_create_autocmd('CursorHold', {
    group = group,
    callback = function(event)
      local clients = vim.lsp.get_clients({ bufnr = event.buf, method = highlight_method })
      if #clients > 0 then
        vim.lsp.buf.document_highlight()
      end
    end,
  })

  vim.api.nvim_create_autocmd({ 'CursorMoved', 'InsertEnter', 'BufLeave' }, {
    group = group,
    callback = function()
      vim.lsp.buf.clear_references()
    end,
  })

  vim.api.nvim_create_autocmd('LspDetach', {
    group = group,
    callback = function(event)
      vim.lsp.util.buf_clear_references(event.buf)
    end,
  })
end

function M.config()
  local servers = require('devtool')
  vim.lsp.config('*', { capabilities = require('blink.cmp').get_lsp_capabilities() })

  for name, get_config in pairs(servers.configs) do
    vim.lsp.config(name, get_config())
  end

  setup_interactions()

  require('mason-lspconfig').setup({
    ensure_installed = servers.ensure_installed,
    automatic_enable = true,
  })

  vim.keymap.set('n', 'grA', function()
    vim.lsp.buf.code_action({
      context = {
        only = { 'source' },
        diagnostics = {},
      },
    })
  end, { desc = 'Source code action' })
end

return M
