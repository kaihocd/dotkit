---A grep list remembers backend continuation offsets, not estimated batch lengths.
---@class picker.picker.GrepPages
---@field page integer
---@field size integer
---@field _offsets table<integer, integer>
local GrepPages = {}
GrepPages.__index = GrepPages

---@return picker.picker.GrepPages
function GrepPages.new()
  return setmetatable({ page = 0, size = 1, _offsets = { [0] = 0 } }, GrepPages)
end

function GrepPages:reset()
  self.page = 0
  self._offsets = { [0] = 0 }
end

---@param size integer
function GrepPages:set_size(size)
  self.size = size
end

---@param page integer
---@return integer
function GrepPages:backend_position(page)
  return self._offsets[page] or 0
end

---@param result picker.picker.Page
function GrepPages:accept(result)
  self._offsets[self.page + 1] = result.next_offset
end

---@param result picker.picker.Page
---@param _ integer
---@param delta integer
---@return boolean changed
---@return integer? target
function GrepPages:move(result, _, delta)
  local next_page = self.page + (delta > 0 and 1 or -1)
  if next_page < 0 or (delta > 0 and not result.more) then
    return false
  end

  self.page = next_page
  return true, delta > 0 and 1 or math.huge
end

---Grep batches retain their configured size when the window changes.
---@param ... integer
---@return integer? target
function GrepPages:resize(...) end

return GrepPages
