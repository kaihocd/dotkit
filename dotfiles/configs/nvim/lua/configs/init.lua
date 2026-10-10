local M = {}

function M.setup()
  require('vim._core.ui2').enable({ msg = { pager = { height = 0.3 } } })
  require('configs.options')
  require('configs.keymaps')
  require('configs.autocmd')
end

return M
