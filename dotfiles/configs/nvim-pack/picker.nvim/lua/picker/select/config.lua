-- Select defaults and per-invocation configuration resolution.
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

local M = {}

-- Merge records, including empty overrides; replace nonempty sequences.
function M.merge(base, overrides)
  local result = vim.deepcopy(base)

  for key, value in pairs(overrides or {}) do
    if
      type(value) == 'table'
      and type(result[key]) == 'table'
      and (next(value) == nil or not vim.islist(value))
    then
      result[key] = M.merge(result[key], value)
    else
      result[key] = vim.deepcopy(value)
    end
  end

  return result
end

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
---@param config picker.select.ResolvedView
---@return picker.select.ResolvedView? config
---@return string? problem
function M.validate(config)
  for _, role in ipairs({ 'root', 'input', 'list', 'preview', 'detail' }) do
    if config[role] ~= nil then
      return nil, 'view.' .. role .. ' is no longer supported; use view.layout'
    end
  end
  if config.layout ~= nil and type(config.layout) ~= 'function' then
    return nil, 'view.layout must be a function'
  end

  if config.format ~= nil and type(config.format) ~= 'function' then
    return nil, 'view.format must be a function'
  end
  if
    type(config.prefix) ~= 'table'
    or type(config.prefix.margin) ~= 'table'
    or not vim.islist(config.prefix.margin)
    or #config.prefix.margin ~= 2
  then
    return nil, 'view.prefix.margin must be { left, right }'
  end
  for _, value in ipairs(config.prefix.margin) do
    if type(value) ~= 'number' or value < 0 or value % 1 ~= 0 then
      return nil, 'view.prefix.margin must contain non-negative integers'
    end
  end

  for _, key in ipairs({ 'min_items', 'max_items', 'min_width', 'max_width' }) do
    local value = config[key]
    if type(value) ~= 'number' or value < 1 or value % 1 ~= 0 then
      return nil, 'view.' .. key .. ' must be a positive integer; got ' .. vim.inspect(value)
    end
  end
  if config.max_items < config.min_items or config.max_width < config.min_width then
    return nil, 'view maximum sizes must be greater than or equal to minimum sizes'
  end

  for _, key in ipairs({ 'padding', 'prefix', 'highlights' }) do
    if type(config[key]) ~= 'table' then
      return nil, 'view.' .. key .. ' must be a table'
    end
  end
  for _, side in ipairs({ 'left', 'right' }) do
    local value = config.padding[side]
    if type(value) ~= 'number' or value < 0 or value % 1 ~= 0 then
      return nil,
        'view.padding.' .. side .. ' must be a non-negative integer; got ' .. vim.inspect(value)
    end
  end
  for _, field in ipairs({ 'text', 'highlight' }) do
    if type(config.prefix[field]) ~= 'string' then
      return nil, 'view.prefix.' .. field .. ' must be a string'
    end
  end
  for _, field in ipairs({ 'prompt', 'current', 'hint' }) do
    if type(config.highlights[field]) ~= 'string' then
      return nil, 'view.highlights.' .. field .. ' must be a string'
    end
  end

  return config
end

return M
