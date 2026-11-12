-- Select-specific configuration surface.
--
-- Defaults live in `picker.config.defaults.select`, shape rules in
-- `picker.config.rules` and domain checks in `picker.config.checks`; this
-- module adapts them to the `nil, problem` style used by the Select UI.

---Validated configuration used by rendering code.
---@class picker.select.ResolvedView
---@field format? function
---@field min_items integer
---@field max_items integer
---@field min_width integer
---@field max_width integer
---@field prefix { text: string, highlight: string, margin: integer[] }
---@field highlights { prompt: string, current: string, hint: string }
---@field padding { left: integer, right: integer }
---@field layout? fun(panes: picker.select.LayoutPanes, context: picker.select.LayoutContext): popup.node

local schema = require('picker.config.schema')
local checks = require('picker.config.checks')

local M = {}

-- Merge records, including empty overrides; replace nonempty sequences.
M.merge = schema.merge

---Resolve one invocation's configuration without mutating caller tables.
---@param options? picker.select.ViewOptions
---@return picker.select.ResolvedView? config
---@return string? problem
function M.options(options)
  if options ~= nil and type(options) ~= 'table' then
    return nil, 'view must be a table'
  end
  local ok, result = pcall(require('picker.config').resolve, 'select', { view = options })
  if not ok then
    return nil, tostring(result)
  end
  ---@cast result picker.SelectConfig
  return result.view
end

---Validate a complete view without supplying defaults.
---@param view picker.select.ResolvedView
---@return picker.select.ResolvedView? config
---@return string? problem
function M.validate(view)
  local problem = checks.select(view)
  if problem then
    return nil, problem
  end
  return view
end

return M
