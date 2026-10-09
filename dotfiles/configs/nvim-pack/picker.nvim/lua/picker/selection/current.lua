-- Operations on the current item in a selection.
local M = {}

---Select the item identified by `key`.
---@generic T
---@param state picker.selection.State<T>
---@param key picker.selection.Key
---@return boolean changed
function M.select(state, key)
  local index = state.index_by_key[key]

  if not index or state.current_index == index then
    return false
  end

  state.current_index = index
  return true
end

---Return whether moving by `delta` stays within the result set.
---@generic T
---@param state picker.selection.State<T>
---@param delta integer
---@return boolean
function M.can_move(state, delta)
  local current_index = state.current_index

  if not current_index or #state.items == 0 then
    return false
  end

  local target_index = current_index + delta
  return target_index >= 1 and target_index <= #state.items
end

---Move the current item by `delta`, clamped to the result boundaries.
---@generic T
---@param state picker.selection.State<T>
---@param delta integer
---@return boolean changed
function M.move(state, delta)
  local current_index = state.current_index

  if not current_index or #state.items == 0 or delta == 0 then
    return false
  end

  local next_index = math.max(1, math.min(#state.items, current_index + delta))

  if next_index == current_index then
    return false
  end

  state.current_index = next_index
  return true
end

return M
