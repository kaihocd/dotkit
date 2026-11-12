-- Prepare result state before committing it to a Selection.

local M = {}

---Validate and index a replacement result set.
---
---All work happens in local tables so callers can commit the result only after
---validation succeeds.
---@generic T
---@param get_key fun(item: T): picker.selection.Key
---@param items T[]
---@param options? picker.selection.ReplaceOptions
---@param previous_key? picker.selection.Key
---@return T[] items
---@return table<picker.selection.Key, integer> index_by_key
---@return integer? current_index
function M.prepare(get_key, items, options, previous_key)
  local next_items = {}
  local next_index = {}

  for index, item in ipairs(items) do
    local key = get_key(item)

    if type(key) ~= 'string' and type(key) ~= 'number' then
      error('Selection key must be a string or number')
    end

    if next_index[key] then
      error(('Duplicate Selection key: %s'):format(key))
    end

    next_items[index] = item
    next_index[key] = index
  end

  local current_index
  if options and options.preserve_current and previous_key then
    current_index = next_index[previous_key]
  end

  return next_items, next_index, current_index or (#next_items > 0 and 1 or nil)
end

return M
