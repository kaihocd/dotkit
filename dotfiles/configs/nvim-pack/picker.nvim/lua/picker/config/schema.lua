-- Structural merging and validation shared by every configuration kind.
--
-- Default values stand in for types: a key that has no default is reported as
-- unsupported. Shapes that a default cannot describe (functions, `false`,
-- open keymaps) are handled by rules supplied by the owning kind, so this
-- module knows nothing about picker or select.

local M = {}

---Records merge recursively; nonempty sequences replace their predecessors.
---@param base table
---@param overrides? table
---@return table
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

---Text placed on one rendered line cannot carry these bytes.
---@param value any
---@return boolean
function M.single_line(value)
  return type(value) == 'string' and value:find('[\r\n\t]') ~= nil
end

---A rule for keys whose value is always a function.
---@param value any
---@param name string
---@return boolean
function M.check_function(value, name)
  if type(value) ~= 'function' then
    error('picker: ' .. name .. ' must be a function', 0)
  end
  return true
end

---A rule for keys rendered on a single line.
---@param value any
---@param name string
---@return boolean
function M.check_single_line(value, name)
  if type(value) ~= 'string' or M.single_line(value) then
    error('picker: ' .. name .. ' must be a single line without tabs', 0)
  end
  return true
end

---A rule for the pane roles that the layout tree replaced.
---@param _ any
---@param name string
---@return boolean
function M.check_retired(_, name)
  local role = name:match('%.([%w_]+)$') or name
  error('picker: view.' .. role .. ' is no longer supported; use view.layout', 0)
end

---Validate a record against a schema whose default values stand in for types.
---
---`rules` maps a level path (`picker.view`) to `key = fun(value, name)`. A rule
---returns true when it fully handled the key; nil falls back to the default
---type check. Paths are compared without the `setup.` prefix so that setup and
---per-invocation overrides share one rule table.
---@param options table
---@param schema table
---@param path string
---@param rules? table<string, table<string, fun(value: any, name: string): boolean?>>
function M.validate_record(options, schema, path, rules)
  if type(options) ~= 'table' then
    error('picker: ' .. path .. ' must be a table', 0)
  end

  local level = rules and rules[(path:gsub('^setup%.', ''))]

  for key, value in pairs(options) do
    local name = path .. '.' .. tostring(key)
    local rule = level and level[key]

    if rule and rule(value, name) then
      -- handled by the owning kind; no default describes this shape
    elseif schema[key] == nil then
      error('picker: unsupported option ' .. name, 0)
    elseif type(schema[key]) == 'table' then
      M.validate_record(value, schema[key], name, rules)
    elseif type(value) ~= type(schema[key]) then
      error('picker: invalid type for ' .. name, 0)
    elseif path:find('.presentation', 1, true) and M.single_line(value) then
      error('picker: ' .. name .. ' must be a single line without tabs', 0)
    end
  end
end

return M
