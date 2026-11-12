-- Public invocation boundary: the shape of `picker.open` options.
--
-- Nested view/keymap shapes are validated by the configuration layer, so this
-- module only rejects keys and modes the API does not define.

local config = require('picker.config')
local invocation = require('picker.config.invocation')

local M = {}

local allowed = {
  mode = true,
  cwd = true,
  on_instance = true,
  view = true,
  keymaps = true,
  search = true,
  preview = true,
}

local modes = { files = true, grep = true }
local tables = { 'view', 'keymaps', 'search', 'preview' }

---Validate the public boundary before loading a backend or allocating UI resources.
---@param options picker.picker.Options
function M.validate(options)
  if type(options) ~= 'table' then
    error('options must be a table', 0)
  end

  for key in pairs(options) do
    if not allowed[key] then
      error('unsupported option: ' .. tostring(key), 0)
    end
  end

  if options.mode ~= nil and not modes[options.mode] then
    error('mode must be files or grep', 0)
  end
  if options.cwd ~= nil and type(options.cwd) ~= 'string' then
    error('cwd must be a directory string', 0)
  end
  if options.on_instance ~= nil and type(options.on_instance) ~= 'function' then
    error('on_instance must be a function', 0)
  end
  for _, key in ipairs(tables) do
    if options[key] ~= nil and type(options[key]) ~= 'table' then
      error(key .. ' must be a table', 0)
    end
  end
end

---@param options picker.picker.Options
---@return picker.picker.ResolvedOptions
---@return picker.PickerConfig settings
function M.resolve(options)
  M.validate(options)

  local resolved = vim.deepcopy(options)
  local declared = resolved.view or {}
  local settings = config.resolve('picker', {
    view = {
      layout = declared.layout,
      presentation = declared.presentation,
      signs = declared.signs,
      icon = declared.icon,
    },
    search = resolved.search,
    preview = resolved.preview,
    keymaps = resolved.keymaps,
  })

  resolved.view = resolved.view or {}
  resolved.view.layout = settings.view.layout
  resolved.view.signs = settings.view.signs
  resolved.view.icon = settings.view.icon
  resolved.keymaps = settings.keymaps
  -- Store declarations, not generated formatter closures, in resume snapshots.
  resolved.view.presentation = settings.view.presentation
  resolved.cwd = invocation.cwd(resolved.cwd)
  ---@cast resolved picker.picker.ResolvedOptions
  return resolved, settings
end

return M
