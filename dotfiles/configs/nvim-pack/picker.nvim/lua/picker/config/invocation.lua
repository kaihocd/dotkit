-- Caller tables become the single resolved form a session consumes.

local M = {}

---A layout may be declared as a bare function; snapshots carry the table form.
---@param options table
---@return table
function M.normalize(options)
  local result = vim.deepcopy(options)
  if result.view and type(result.view.layout) == 'function' then
    result.view.layout = { build = result.view.layout }
  end
  return result
end

---Absolute working directory for one invocation; the only filesystem read in
---the configuration layer, shared by open and resume.
---@param path? string
---@return string
function M.cwd(path)
  return vim.uv.fs_realpath(path or vim.fn.getcwd()) or path or vim.fn.getcwd()
end

return M
