local Selection = require('picker.selection')

---Backend-normalized entry. Display text never determines identity or opening.
---@class picker.picker.Entry
---@field path string Absolute file path.
---@field display string Relative display path.
---@field line? integer 1-based line.
---@field col? integer 0-based byte column.
---@field content? string Single-line grep snippet.
---@field match_ranges? integer[][] Half-open, 0-based byte ranges in display.
---@field content_matches? integer[][] Half-open, 0-based byte ranges in content.
---@field git_status? string

---Owns the visible selection and ordered marks, independently of display rows.
---@class picker.picker.PickerSelection
---@field _selection picker.Selection<picker.picker.Entry>
local PickerSelection = {}
PickerSelection.__index = PickerSelection

---Length-prefix the path so delimiters in filenames cannot collide with locations.
---@param entry picker.picker.Entry
---@return string
local function identity(entry)
  return #entry.path .. ':' .. entry.path .. ':' .. (entry.line or 0) .. ':' .. (entry.col or 0)
end

---@return picker.picker.PickerSelection
function PickerSelection.new()
  ---@type picker.selection.Options<picker.picker.Entry>
  local options = { key = identity }
  return setmetatable({ _selection = Selection.new(options) }, PickerSelection)
end

---Apply one result page atomically; marks survive page and query replacement.
---@param items picker.picker.Entry[]
---@param preserve_current? boolean
---@param target? integer Visible item position, never a display row.
function PickerSelection:replace(items, preserve_current, target)
  self._selection:replace(items, { preserve_current = preserve_current == true })
  if target and #items > 0 then
    self._selection:move(target - (self._selection:current_index() or 1))
  end
end

---@return picker.picker.Entry[]
function PickerSelection:entries()
  return self._selection:items()
end

---@return picker.picker.Entry?
function PickerSelection:current()
  return self._selection:current()
end

---@return integer?
function PickerSelection:current_index()
  return self._selection:current_index()
end

---@param delta integer
---@return boolean
function PickerSelection:can_move(delta)
  return self._selection:can_move(delta)
end

---@param delta integer
---@return boolean changed
function PickerSelection:move(delta)
  return self._selection:move(delta)
end

---@return boolean changed
function PickerSelection:toggle_mark()
  return self._selection:toggle_mark()
end

---@param entry picker.picker.Entry
---@return boolean
function PickerSelection:is_marked(entry)
  return self._selection:is_marked(identity(entry))
end

---@return picker.picker.Entry[]
function PickerSelection:marked_items()
  return self._selection:marked_items()
end

---@param entries picker.picker.Entry[]
function PickerSelection:restore_marks(entries)
  self._selection:replace_marks(vim.deepcopy(entries))
end

---@return integer
function PickerSelection:marked_count()
  return self._selection:marked_count()
end

---Current-file prefetch candidates, deduplicated without losing proximity order.
---@param radius integer
---@return picker.picker.Entry[]
function PickerSelection:nearby(radius)
  local entries = self:entries()
  local current = self._selection:current_index()
  if not current then
    return {}
  end
  local items, seen = {}, {}
  for index = math.max(1, current - radius), math.min(#entries, current + radius) do
    local entry = entries[index]
    if not seen[entry.path] then
      seen[entry.path] = true
      items[#items + 1] = entry
    end
  end
  return items
end

return PickerSelection
