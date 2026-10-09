local keymap = require('tab-bar.keymap')
local title = require('tab-bar.title')

local M = {}

function M.setup(config)
  keymap.apply(config)
  title.register()
end

return M
