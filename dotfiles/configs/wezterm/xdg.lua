local M = {}

---Optional XDG override; GUI sessions need not publish it.
local XDG_STATE_HOME_ENV = 'XDG_STATE_HOME'

---Resolve State Home without depending on shell startup or session publication.
---@param name string
---@return string
local function required_directory(name)
  local directory = os.getenv(name)
  if not directory or directory == '' then
    local home = os.getenv('HOME')
    if not home or home == '' then
      error('DOTFILES_ERROR HOME is required when ' .. name .. ' is unset')
    end
    directory = home .. '/.local/state'
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
