-- Autocmds owned by one invocation, grouped so teardown is atomic.
--
-- Each invocation gets its own group: a shared group name would let a second
-- session clear the listeners a first one still uses, because creating a group
-- with `clear = true` wipes it. The name prefix keeps `:autocmd` readable, and
-- deleting the group removes every listener in one step, including the ones a
-- partial setup already created.

local M = {}

local counter = 0

---@class picker.ui.Augroup
---@field private _id integer?
local Augroup = {}
Augroup.__index = Augroup

---@param prefix string Entry point name, so `:autocmd` shows the owner.
---@return picker.ui.Augroup
function M.new(prefix)
  counter = counter + 1
  local group = vim.api.nvim_create_augroup(('%s:%d'):format(prefix, counter), { clear = true })
  return setmetatable({ _id = group }, Augroup)
end

---Create one listener inside the group; the caller never passes `group`.
---@param event string|string[]
---@param options table
---@return integer
function Augroup:create(event, options)
  local id = assert(self._id, 'picker: augroup is closed')
  return vim.api.nvim_create_autocmd(event, vim.tbl_extend('force', options, { group = id }))
end

---Remove every listener created through this group; closing twice is a no-op.
function Augroup:close()
  local id = self._id
  if not id then
    return
  end
  self._id = nil
  pcall(vim.api.nvim_del_augroup_by_id, id)
end

return M
