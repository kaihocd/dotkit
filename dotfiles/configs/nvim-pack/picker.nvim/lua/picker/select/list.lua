-- Select-specific filtering and original-item lookup. No windows or callbacks.

local Selection = require('picker.selection')

---An original item with prepared display and search text.
---@class picker.select.Entry<T>
---@field item T Original value.
---@field index integer Original 1-based index; also the selection key.
---@field text string Single-line text without row decoration.
---@field full_text string Original formatted text, before list-only newline flattening.
---@field search string Normalized search text.
---@field row picker.list.Row

---Internal Select logic, without windows or callbacks.
---Selection alone owns the current item.
---@class picker.select.SelectList<T>
---@field _entries picker.select.Entry<T>[] All entries in original order.
---@field _selection picker.Selection<picker.select.Entry<T>> Visible selection.
---@field _query string Last normalized query.
---@field _normalize fun(text: string): string
local SelectList = {}
SelectList.__index = SelectList

---Prepare caller-owned items once; selection keys are their original indices.
---@generic T
---@param items T[]
---@param options? picker.select.Options<T>
---@return picker.select.SelectList<T>
function SelectList.new(items, options)
  local entries = {}
  local normalize = options and options.normalize or string.lower
  local formatter = options and options.view and options.view.format
  local index_width = #tostring(#items)

  for index, item in ipairs(items) do
    local text = options and options.format_item and options.format_item(item) or tostring(item)
    local row = formatter and formatter(item, { index = index, text = text })
      or {
        content = {
          { string.format('%' .. index_width .. 'd. ', index), 'Comment' },
          { text },
        },
      }
    local display = require('picker.content').project(row)
    local original = {}
    for _, segment in ipairs(row.content) do
      original[#original + 1] = segment[1]
    end
    entries[index] = {
      item = item,
      index = index,
      text = display,
      full_text = formatter and table.concat(original) or text,
      search = normalize(text),
      row = row,
    }
  end

  local selection_options = {
    key = function(entry)
      return entry.index
    end,
  }
  local selection = Selection.new(selection_options)
  selection:replace(entries)

  return setmetatable({
    _entries = entries,
    _selection = selection,
    _query = '',
    _normalize = normalize,
  }, SelectList)
end

---Filter literally without case sensitivity, preserving the current identity.
---@generic T
---@param self picker.select.SelectList<T>
---@param query string
---@return boolean changed
function SelectList.set_query(self, query)
  local normalized = self._normalize(query)
  if normalized == self._query then
    return false
  end

  local original_index = normalized:match('^%d+$') and tonumber(normalized)
  local visible = {}
  for _, entry in ipairs(self._entries) do
    local matches
    if original_index then
      matches = entry.index == original_index
    else
      matches = entry.search:find(normalized, 1, true) ~= nil
    end

    if matches then
      visible[#visible + 1] = entry
    end
  end

  self._selection:replace(visible, { preserve_current = true })
  self._query = normalized
  return true
end

---Return visible entries in their original order.
---@generic T
---@param self picker.select.SelectList<T>
---@return picker.select.Entry<T>[]
function SelectList.entries(self)
  return self._selection:items()
end

---Copied display projection; callers cannot mutate the candidate collection.
---@generic T
---@param self picker.select.SelectList<T>
---@return string[]
function SelectList.texts(self)
  local texts = {}
  for _, entry in ipairs(self:entries()) do
    texts[#texts + 1] = entry.text
  end
  return texts
end

---Copied formatted projection for every list-content render, including first mount.
---@return picker.list.Row[]
function SelectList:rows()
  local rows = {}
  for _, entry in ipairs(self:entries()) do
    rows[#rows + 1] = vim.deepcopy(entry.row)
  end
  return rows
end

---Return the position in filtered results, not an original index or UI row.
---@generic T
---@param self picker.select.SelectList<T>
---@return integer?
function SelectList.current_index(self)
  return self._selection:current_index()
end

---Select a visible entry by original index; hidden or unknown entries do nothing.
---@generic T
---@param self picker.select.SelectList<T>
---@param original_index integer
---@return boolean changed
function SelectList.select(self, original_index)
  return self._selection:select(original_index)
end

---Move within visible entries; never wrap at boundaries.
---@generic T
---@param self picker.select.SelectList<T>
---@param delta integer
---@return boolean changed
function SelectList.move(self, delta)
  return self._selection:move(delta)
end

---Resolve the current choice without invoking callbacks or closing anything.
---@generic T
---@param self picker.select.SelectList<T>
---@return T? item
---@return integer? original_index
function SelectList.choice(self)
  local entry = self._selection:current()
  if entry == nil then
    return nil, nil
  end

  return entry.item, entry.index
end

return SelectList
