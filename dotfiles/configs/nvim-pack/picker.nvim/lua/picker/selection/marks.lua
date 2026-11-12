-- Operations on marked items in a selection.

local M = {}

---Toggle the mark on the current item.
---@generic T
---@param state picker.selection.State<T>
---@param get_key fun(item: T): picker.selection.Key
---@return boolean changed
function M.toggle(state, get_key)
  local index = state.current_index

  if not index then
    return false
  end

  local item = state.items[index]
  local key = get_key(item)

  if state.marked[key] ~= nil then
    state.marked[key] = nil

    for mark_index, marked_key in ipairs(state.mark_order) do
      if marked_key == key then
        table.remove(state.mark_order, mark_index)
        break
      end
    end
  else
    state.marked[key] = item
    state.mark_order[#state.mark_order + 1] = key
  end

  return true
end

return M
