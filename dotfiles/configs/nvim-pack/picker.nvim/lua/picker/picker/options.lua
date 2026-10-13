local M = {}

---Validate the public boundary before loading a backend or allocating UI resources.
---@param options picker.picker.Options
function M.validate(options)
  if type(options) ~= 'table' then
    error('options must be a table', 0)
  end
  for key in pairs(options) do
    if
      key ~= 'mode'
      and key ~= 'cwd'
      and key ~= 'on_instance'
      and key ~= 'view'
      and key ~= 'keymaps'
      and key ~= 'search'
      and key ~= 'preview'
    then
      error('unsupported option: ' .. tostring(key), 0)
    end
  end
  if options.mode ~= nil and options.mode ~= 'files' and options.mode ~= 'grep' then
    error('mode must be files or grep', 0)
  end
  if options.cwd ~= nil and type(options.cwd) ~= 'string' then
    error('cwd must be a directory string', 0)
  end
  if options.view ~= nil and type(options.view) ~= 'table' then
    error('view must be a table', 0)
  end
  if options.view then
    for key in pairs(options.view) do
      if key ~= 'layout' and key ~= 'presentation' and key ~= 'signs' and key ~= 'icon' then
        error('unsupported view field: ' .. tostring(key), 0)
      end
    end
    for _, role in ipairs({ 'root', 'input', 'list', 'preview', 'detail' }) do
      if options.view[role] ~= nil then
        error('view.' .. role .. ' is no longer supported; use view.layout', 0)
      end
    end
    local layout = options.view.layout
    if layout ~= nil and type(layout) ~= 'function' and type(layout) ~= 'table' then
      error('view.layout must be a function or table', 0)
    end
    if type(layout) == 'table' then
      for key in pairs(layout) do
        if key ~= 'width_ratio' and key ~= 'height_ratio' and key ~= 'build' then
          error('unsupported view.layout field: ' .. tostring(key), 0)
        end
      end
      for _, key in ipairs({ 'width_ratio', 'height_ratio' }) do
        local ratio = layout[key]
        if ratio ~= nil and (type(ratio) ~= 'number' or not (ratio > 0 and ratio <= 1)) then
          error('view.layout.' .. key .. ' must be a number in (0, 1]', 0)
        end
      end
      if layout.build ~= nil and type(layout.build) ~= 'function' then
        error('view.layout.build must be a function', 0)
      end
    end
    if
      options.view.icon ~= nil
      and options.view.icon ~= false
      and type(options.view.icon) ~= 'function'
    then
      error('view.icon must be false or a function', 0)
    end
  end
  if options.keymaps ~= nil and type(options.keymaps) ~= 'table' then
    error('keymaps must be a table', 0)
  end
  local modes = {
    n = true,
    i = true,
    v = true,
    x = true,
    s = true,
    o = true,
    c = true,
    t = true,
    l = true,
    [''] = true,
    ['!'] = true,
  }
  for mode, mappings in pairs(options.keymaps or {}) do
    if not modes[mode] then
      error('keymaps mode must be a native Neovim mapping mode: ' .. tostring(mode), 0)
    end
    if type(mappings) ~= 'table' then
      error('keymaps[' .. mode .. '] must be a table', 0)
    end
    for lhs, declaration in pairs(mappings) do
      if type(lhs) ~= 'string' or lhs == '' then
        error('keymaps[' .. mode .. '] keys must be non-empty strings', 0)
      end
      if
        declaration ~= false
        and type(declaration) ~= 'string'
        and type(declaration) ~= 'function'
      then
        error('keymaps[' .. mode .. '][' .. lhs .. '] must be false, a string or a function', 0)
      end
    end
  end
end

---@param options picker.picker.Options
---@return picker.picker.ResolvedOptions
---@return picker.PickerConfig settings
function M.resolve(options)
  M.validate(options)
  local resolved = vim.deepcopy(options)
  resolved.view = resolved.view or {}
  local settings = require('picker.config').resolve('picker', {
    view = {
      layout = resolved.view.layout,
      presentation = resolved.view.presentation,
      signs = resolved.view.signs,
      icon = resolved.view.icon,
    },
    search = resolved.search,
    preview = resolved.preview,
    keymaps = resolved.keymaps,
  }, resolved.mode)
  resolved.view.layout = settings.view.layout
  resolved.view.signs = settings.view.signs
  resolved.view.icon = settings.view.icon
  resolved.keymaps = settings.keymaps
  -- Store declarations, not generated formatter closures, in resume snapshots.
  resolved.view.presentation = settings.view.presentation
  resolved.cwd = vim.uv.fs_realpath(resolved.cwd or vim.fn.getcwd())
    or resolved.cwd
    or vim.fn.getcwd()
  ---@cast resolved picker.picker.ResolvedOptions
  return resolved, settings
end

return M
