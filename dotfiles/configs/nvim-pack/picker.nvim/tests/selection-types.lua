-- Static fixture: constructor inference preserves an explicitly typed Options.
-- LuaLS does not infer the item type from an unannotated options table's callback.
local Selection = require('picker.selection')

---@class SelectionTestItem
---@field id string
---@field label string

---@param item SelectionTestItem
---@return string
local function get_key(item)
  return item.id
end

---@type picker.selection.Options<SelectionTestItem>
local options = { key = get_key }
local selection = Selection.new(options)
selection:replace({ { id = 'a', label = 'Alpha' } })

---@param item SelectionTestItem
local function consume(item)
  assert(item.label)
end

local item = selection:current()
if item ~= nil then
  consume(item)
end

for _, entry in ipairs(selection:items()) do
  consume(entry)
end

for _, entry in ipairs(selection:marked_items()) do
  consume(entry)
end

-- Negative cases are injected into a temporary workspace by selection-types.ts.
