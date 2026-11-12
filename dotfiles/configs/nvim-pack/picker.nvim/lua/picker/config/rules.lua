-- Shape rules for configuration values, keyed by level path.
--
-- Defaults are pure data (`picker/config/defaults/*`); a rule exists only where
-- no default value can describe the accepted shape. Paths are shared by
-- `setup()` and `resolve()`: the walker strips the `setup.` prefix, so
-- `setup.picker.view` and `picker.view` resolve to the same entry.
--
-- `rule(value, name)` returns true when it has fully handled the value and
-- raises `picker: <problem>` otherwise.

local schema = require('picker.config.schema')
local keys = require('picker.config.defaults.keys')

---A mapping table maps native modes to `lhs = action` declarations. The action
---is a name resolved against the action set, a raw key sequence, or false to
---remove that mapping.
---@param value any
---@param name string
---@return boolean
local function check_keymaps(value, name)
  if type(value) ~= 'table' then
    error('picker: ' .. name .. ' must be a table', 0)
  end

  for mode, mappings in pairs(value) do
    if not keys.modes[mode] then
      error('picker: keymaps mode must be a native Neovim mapping mode: ' .. tostring(mode), 0)
    end
    if type(mappings) ~= 'table' then
      error('picker: keymaps[' .. tostring(mode) .. '] must be a table', 0)
    end
    for lhs, declaration in pairs(mappings) do
      if type(lhs) ~= 'string' or lhs == '' then
        error('picker: keymaps[' .. tostring(mode) .. '] keys must be non-empty strings', 0)
      end
      if
        declaration ~= false
        and type(declaration) ~= 'string'
        and type(declaration) ~= 'function'
      then
        error(
          'picker: keymaps[' .. tostring(mode) .. '][' .. lhs .. '] must be false, a string or a function',
          0
        )
      end
    end
  end

  return true
end

---@param value any
---@param name string
---@return boolean
local function check_layout(value, name)
  if type(value) == 'function' then
    return true
  end
  if type(value) ~= 'table' then
    error('picker: ' .. name .. ' must be a function or table', 0)
  end
  for key in pairs(value) do
    if key ~= 'width_ratio' and key ~= 'height_ratio' and key ~= 'build' then
      error('picker: unsupported option ' .. name .. '.' .. tostring(key), 0)
    end
  end
  for _, key in ipairs({ 'width_ratio', 'height_ratio' }) do
    local ratio = value[key]
    if ratio ~= nil and (type(ratio) ~= 'number' or not (ratio > 0 and ratio <= 1)) then
      error('picker: ' .. name .. '.' .. key .. ' must be a number in (0, 1]', 0)
    end
  end
  if value.build ~= nil and type(value.build) ~= 'function' then
    error('picker: ' .. name .. '.build must be a function', 0)
  end
  return true
end

---@param value any
---@param name string
---@return boolean
local function check_icon(value, name)
  if value ~= false and type(value) ~= 'function' then
    error('picker: ' .. name .. ' must be false or a function', 0)
  end
  return true
end

---Copy that differs per search mode may be declared once for both, or keyed by
---mode so files and grep keep different prefixes.
---@param value any
---@param name string
---@return boolean
local function check_prefix_text(value, name)
  if type(value) == 'string' then
    return schema.check_single_line(value, name)
  end
  if type(value) ~= 'table' then
    error('picker: ' .. name .. ' must be a string or a { files, grep } table', 0)
  end
  for key, text in pairs(value) do
    if key ~= 'files' and key ~= 'grep' then
      error('picker: unsupported option ' .. name .. '.' .. tostring(key), 0)
    end
    schema.check_single_line(text, name .. '.' .. key)
  end
  return true
end

local retired_roles = { 'root', 'input', 'list', 'preview', 'detail' }

local M = {
  picker = { keymaps = check_keymaps },
  select = { keymaps = check_keymaps },
  ['picker.view'] = { layout = check_layout, icon = check_icon },
  ['picker.view.presentation'] = { format = schema.check_function },
  ['picker.view.presentation.prefix'] = { text = check_prefix_text },
  ['select.view'] = { layout = schema.check_function, format = schema.check_function },
}

for _, role in ipairs(retired_roles) do
  M['picker.view'][role] = schema.check_retired
  M['select.view'][role] = schema.check_retired
end

return M
