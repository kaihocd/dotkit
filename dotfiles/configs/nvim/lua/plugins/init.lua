local M = {}

function M.setup()
  -- Feature specs merge in this order; later explicit settings take precedence.
  -- Dependencies still determine plugin loading order.

  ---@type pack.UserSpec[]
  local specs = {}

  vim.list_extend(specs, require('plugins.ui'))
  vim.list_extend(specs, require('plugins.explorer'))
  vim.list_extend(specs, require('plugins.editing'))
  vim.list_extend(specs, require('plugins.devtool'))
  vim.list_extend(specs, require('plugins.git'))
  vim.list_extend(specs, require('plugins.ai'))

  require('plugins.pack').setup(specs)
end

return M
