-- Domain checks for a complete configuration.
--
-- Shape rules reject a value in isolation; these checks compare fields, which is
-- only meaningful once defaults and overrides have been merged. Each check
-- returns a problem string so the caller owns the `picker:` prefix.

local M = {}

-- A marker overlays column 1 of the list row and the row text starts at column 3
-- (`picker/picker/window/render.lua`: STATUS_COLUMN, PADDING.left), so two cells
-- is what the layout reserves. Measured with `ambiwidth=double`: a double-width
-- glyph fills the padding and leaves the text at its column. Keep these in step.
local MARKER_CELLS = 2

local function positive_integer(value)
  return type(value) == 'number' and value >= 1 and value % 1 == 0
end

local function non_negative_integer(value)
  return type(value) == 'number' and value >= 0 and value % 1 == 0
end

---@param value any
---@param name string
---@return string?
local function cell_problem(value, name)
  if
    not vim.islist(value)
    or #value ~= 2
    or type(value[1]) ~= 'string'
    or value[1]:find('[\r\n\t]')
    or vim.fn.strdisplaywidth(value[1]) > MARKER_CELLS
  then
    return name .. ' must contain at most two display cells and a highlight'
  end
end

---@param value any
---@param name string
---@return string?
local function margin_problem(value, name)
  if not vim.islist(value) or #value ~= 2 then
    return name .. ' must contain two non-negative integers'
  end
  for _, side in ipairs(value) do
    if not non_negative_integer(side) then
      return name .. ' must contain non-negative integers'
    end
  end
end

---@param config picker.PickerConfig
---@return string?
function M.picker(config)
  local signs = config.view.signs
  local ratio = signs.staged_foreground_ratio
  if not (type(ratio) == 'number' and ratio >= 0 and ratio <= 1) then
    return 'staged_foreground_ratio must be in [0, 1]'
  end
  for name, marker in pairs(signs.git) do
    local problem = cell_problem(marker, 'git.' .. name)
    if problem then
      return problem
    end
  end

  local presentation = config.view.presentation
  local problem = margin_problem(presentation.prefix.margin, 'prefix.margin')
  if problem then
    return problem
  end
  if vim.fn.strdisplaywidth(presentation.marker.text) > MARKER_CELLS then
    return 'view.presentation.marker.text must contain at most two display cells'
  end

  for _, key in ipairs({ 'width_ratio', 'height_ratio' }) do
    local value = config.view.layout[key]
    if not (type(value) == 'number' and value > 0 and value <= 1) then
      return 'layout ratios must be in (0, 1]'
    end
  end

  for key, value in pairs(config.search) do
    local minimum = key == 'debounce_ms' and 0 or 1
    if not (non_negative_integer(value) and value >= minimum) then
      return 'invalid search.' .. key
    end
  end
  for key, value in pairs(config.preview) do
    local minimum = (key == 'radius' or key == 'max_prefetch') and 0 or 1
    if not (non_negative_integer(value) and value >= minimum) then
      return 'invalid preview.' .. key
    end
  end
end

---@param view picker.select.ResolvedView
---@return string?
function M.select(view)
  for _, role in ipairs({ 'root', 'input', 'list', 'preview', 'detail' }) do
    if view[role] ~= nil then
      return 'view.' .. role .. ' is no longer supported; use view.layout'
    end
  end
  if view.layout ~= nil and type(view.layout) ~= 'function' then
    return 'view.layout must be a function'
  end
  if view.format ~= nil and type(view.format) ~= 'function' then
    return 'view.format must be a function'
  end

  local problem = margin_problem(view.prefix and view.prefix.margin, 'view.prefix.margin')
  if problem then
    return problem
  end

  for _, key in ipairs({ 'min_items', 'max_items', 'min_width', 'max_width' }) do
    if not positive_integer(view[key]) then
      return 'view.' .. key .. ' must be a positive integer; got ' .. vim.inspect(view[key])
    end
  end
  if view.max_items < view.min_items or view.max_width < view.min_width then
    return 'view maximum sizes must be greater than or equal to minimum sizes'
  end

  for _, key in ipairs({ 'padding', 'prefix', 'highlights' }) do
    if type(view[key]) ~= 'table' then
      return 'view.' .. key .. ' must be a table'
    end
  end
  for _, side in ipairs({ 'left', 'right' }) do
    if not non_negative_integer(view.padding[side]) then
      return 'view.padding.' .. side .. ' must be a non-negative integer; got ' .. vim.inspect(view.padding[side])
    end
  end
  for _, field in ipairs({ 'text', 'highlight' }) do
    if type(view.prefix[field]) ~= 'string' then
      return 'view.prefix.' .. field .. ' must be a string'
    end
  end
  for _, field in ipairs({ 'prompt', 'current', 'hint' }) do
    if type(view.highlights[field]) ~= 'string' then
      return 'view.highlights.' .. field .. ' must be a string'
    end
  end
end

return M
