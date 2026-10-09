---Preview snapshots only. Content owns version checks; this object owns capacity/recency.
---@class picker.picker.PreviewCache
---@field _items table<string, {stamp: string, lines: string[], bytes: integer}>
---@field _order string[]
---@field _bytes integer
---@field _max_files integer
---@field _max_bytes integer
local Cache = {}
Cache.__index = Cache

---@param max_files integer
---@param max_bytes integer
---@return picker.picker.PreviewCache
function Cache.new(max_files, max_bytes)
  return setmetatable(
    { _items = {}, _order = {}, _bytes = 0, _max_files = max_files, _max_bytes = max_bytes },
    Cache
  )
end

---@param path string
function Cache:remove(path)
  local item = self._items[path]
  if not item then
    return
  end
  self._bytes = self._bytes - item.bytes
  self._items[path] = nil
  for index, key in ipairs(self._order) do
    if key == path then
      table.remove(self._order, index)
      break
    end
  end
end

---@param path string
---@param stamp string
---@return string[]?
function Cache:get(path, stamp)
  local item = self._items[path]
  if not item then
    return
  end
  self:remove(path)
  if item.stamp ~= stamp then
    return
  end
  self._items[path] = item
  self._bytes = self._bytes + item.bytes
  self._order[#self._order + 1] = path
  return vim.list_slice(item.lines)
end

---@param path string
---@param stamp string
---@param lines string[]
function Cache:put(path, stamp, lines)
  self:remove(path)
  local bytes = 0
  for _, line in ipairs(lines) do
    bytes = bytes + #line + 1
  end
  if self._max_files == 0 or bytes > self._max_bytes then
    return
  end
  self._items[path] = { stamp = stamp, lines = vim.list_slice(lines), bytes = bytes }
  self._order[#self._order + 1] = path
  self._bytes = self._bytes + bytes
  while #self._order > self._max_files or self._bytes > self._max_bytes do
    self:remove(self._order[1])
  end
end

function Cache:clear()
  self._items, self._order, self._bytes = {}, {}, 0
end

return Cache
