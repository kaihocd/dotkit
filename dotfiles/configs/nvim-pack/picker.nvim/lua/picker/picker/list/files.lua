---A file list uses fixed-size pages and absolute logical item positions.
---@class picker.picker.FilePages
---@field page integer
---@field size integer
local FilePages = {}
FilePages.__index = FilePages

---@return picker.picker.FilePages
function FilePages.new()
  return setmetatable({ page = 0, size = 1 }, FilePages)
end

function FilePages:reset()
  self.page = 0
end

---@param size integer
function FilePages:set_size(size)
  self.page = math.floor(self.page * self.size / size)
  self.size = size
end

---@param page integer
---@return integer
function FilePages:backend_position(page)
  return page
end

---@param ... picker.picker.Page
function FilePages:accept(...) end

---@param result picker.picker.Page
---@param index integer
---@param delta integer
---@return boolean changed
---@return integer? target
function FilePages:move(result, index, delta)
  if result.total == 0 then
    return false, index
  end

  local position = self.page * self.size + index - 1 + delta
  position = math.max(0, math.min(result.total - 1, position))

  local page = math.floor(position / self.size)
  local changed = page ~= self.page
  self.page = page

  return changed, position % self.size + 1
end

---@param size integer
---@param index integer
---@return integer? target
function FilePages:resize(size, index)
  if size == self.size then
    return
  end

  local position = self.page * self.size + index - 1
  self.size = size
  self.page = math.floor(position / size)

  return position % size + 1
end

return FilePages
