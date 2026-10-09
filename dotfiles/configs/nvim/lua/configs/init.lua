local M = {}

function M.setup()
  require('vim._core.ui2').enable({})
  require('configs.options')
  require('configs.keymaps')
  require('configs.autocmd')
end

return M
