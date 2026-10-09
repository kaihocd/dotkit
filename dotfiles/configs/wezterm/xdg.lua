local M = {}

---Environment variable published by Profiles.
local XDG_STATE_HOME_ENV = 'XDG_STATE_HOME'

---Return a required absolute directory from the Profiles environment.
---@param name string
---@return string
local function required_directory(name)
  local directory = os.getenv(name)
  if not directory or directory == '' then
    error('DOTFILES_ERROR Profiles XDG environment is unavailable: ' .. name)
  end
  if directory:sub(1, 1) ~= '/' then
    error('DOTFILES_ERROR ' .. name .. ' must be absolute: ' .. directory)
  end
  return directory
end

---Resolve a path relative to XDG State Home.
---@param relative_path string
---@return string
function M.state_path(relative_path)
  if relative_path == '' or relative_path:sub(1, 1) == '/' then
    error('DOTFILES_ERROR XDG state path must be relative: ' .. relative_path)
  end
  return required_directory(XDG_STATE_HOME_ENV) .. '/' .. relative_path
end

return M
