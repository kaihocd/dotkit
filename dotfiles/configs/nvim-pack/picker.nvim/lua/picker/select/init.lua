local SelectPanel = require('picker.select.panel')
local M = {}

---Open Select without installing a vim.ui override.
---@generic T
---@param items T[]
---@param options? picker.select.Options<T>
---@param on_choice fun(item: T?, index: integer?)
function M.open(items, options, on_choice)
  local session = SelectPanel.new(items, options or {}, on_choice)
  if session then
    SelectPanel.open(session)
  end
end

return M
