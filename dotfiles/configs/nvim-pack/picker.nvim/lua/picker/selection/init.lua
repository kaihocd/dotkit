-- Public facade for Picker's selection state.
--
-- This is an internal Picker module. It owns the mutable state while the
-- focused operation modules implement result, current-item, and mark logic.
local current = require('picker.selection.current')
local marks = require('picker.selection.marks')
local results = require('picker.selection.results')

local Selection = {}
Selection.__index = Selection

---Create an empty selection model.
---@generic T
---@param options picker.selection.Options<T>
---@return picker.Selection<T>
function Selection.new(options)
  return setmetatable({
    _get_key = assert(options.key),
    _state = {
      items = {},
      index_by_key = {},
      current_index = nil,
      marked = {},
      mark_order = {},
    },
  }, Selection)
end

---Replace the current result set.
---@generic T
---@param self picker.Selection<T>
---@param items T[]
---@param options? picker.selection.ReplaceOptions
function Selection.replace(self, items, options)
  local previous_key = Selection.current_key(self)
  local next_items, next_index, next_current =
    results.prepare(self._get_key, items, options, previous_key)

  self._state.items = next_items
  self._state.index_by_key = next_index
  self._state.current_index = next_current
end

---Return a copy of the current result list.
---@generic T
---@param self picker.Selection<T>
---@return T[]
function Selection.items(self)
  local items = {}

  for index, item in ipairs(self._state.items) do
    items[index] = item
  end

  return items
end

---@generic T
---@param self picker.Selection<T>
---@return integer
function Selection.count(self)
  return #self._state.items
end

---Return the current item, if the result set is not empty.
---@generic T
---@param self picker.Selection<T>
---@return T?
function Selection.current(self)
  local index = self._state.current_index
  return index and self._state.items[index]
end

---@generic T
---@param self picker.Selection<T>
---@return integer?
function Selection.current_index(self)
  return self._state.current_index
end

---@generic T
---@param self picker.Selection<T>
---@return picker.selection.Key?
function Selection.current_key(self)
  local item = Selection.current(self)
  if item == nil then
    return nil
  end

  return self._get_key(item)
end

---Select an item by its stable key.
---@generic T
---@param self picker.Selection<T>
---@param key picker.selection.Key
---@return boolean changed
function Selection.select(self, key)
  return current.select(self._state, key)
end

---Return whether moving by `delta` stays within the results.
---@generic T
---@param self picker.Selection<T>
---@param delta integer
---@return boolean
function Selection.can_move(self, delta)
  return current.can_move(self._state, delta)
end

---Move the current item by `delta`.
---@generic T
---@param self picker.Selection<T>
---@param delta integer
---@return boolean changed
function Selection.move(self, delta)
  return current.move(self._state, delta)
end

---Toggle the mark on the current item.
---@generic T
---@param self picker.Selection<T>
---@return boolean changed
function Selection.toggle_mark(self)
  return marks.toggle(self._state, self._get_key)
end

---@generic T
---@param self picker.Selection<T>
---@param key picker.selection.Key
---@return boolean
function Selection.is_marked(self, key)
  return self._state.marked[key] ~= nil
end

---@generic T
---@param self picker.Selection<T>
---@return integer
function Selection.marked_count(self)
  return #self._state.mark_order
end

---@generic T
---@param self picker.Selection<T>
---@return T[]
function Selection.marked_items(self)
  local items = {}

  for _, key in ipairs(self._state.mark_order) do
    items[#items + 1] = self._state.marked[key]
  end

  return items
end

---Replace ordered marks atomically, independently of the visible results.
---@generic T
---@param self picker.Selection<T>
---@param items T[]
function Selection.replace_marks(self, items)
  local next_marks, order = {}, {}
  for _, item in ipairs(items) do
    local key = self._get_key(item)
    if (type(key) ~= 'string' and type(key) ~= 'number') or key ~= key then
      error('picker.selection: mark key must be a string or a non-NaN number', 0)
    end
    if next_marks[key] == nil then
      next_marks[key] = item
      order[#order + 1] = key
    end
  end
  self._state.marked, self._state.mark_order = next_marks, order
end

---Clear all marks without changing the current item or results.
---@generic T
---@param self picker.Selection<T>
function Selection.clear_marks(self)
  self._state.marked = {}
  self._state.mark_order = {}
end

return Selection
