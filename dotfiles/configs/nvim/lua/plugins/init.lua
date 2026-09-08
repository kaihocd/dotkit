local M = {}

function M.setup()
  -- Pack keeps the first declaration: register shared configuration before
  -- consumers repeat its path in their dependency lists.
  local specs = {}
  vim.list_extend(specs, require('plugins.ui'))
  vim.list_extend(specs, require('plugins.editor'))
  require('plugins.pack').setup(specs)
end

return M
