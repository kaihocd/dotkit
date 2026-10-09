local store = require('pack.store')

local M = {}

local function modules(spec)
  if spec.main then
    return { spec.main }
  end
  local stripped = spec.name:gsub('%.nvim$', '')
  return stripped == spec.name and { spec.name } or { spec.name, stripped }
end

local function auto_config(spec)
  for _, name in ipairs(modules(spec)) do
    local ok, module = pcall(require, name)
    if ok then
      if type(module) == 'table' and type(module.setup) == 'function' then
        module.setup(spec.opts or {})
      elseif spec.opts ~= nil or spec.main then
        error('Plugin ' .. spec.name .. ' module ' .. name .. ' has no setup function', 0)
      end
      return
    end
    -- Only an absent entry is optional; errors inside an entry must propagate.
    local missing = "module '" .. name .. "' not found:"
    if type(module) ~= 'string' or module:sub(1, #missing) ~= missing then
      error('Plugin ' .. spec.name .. ' module ' .. name .. ': ' .. tostring(module), 0)
    end
  end
  if spec.opts ~= nil or spec.main then
    error('Unable to find Lua module for plugin ' .. spec.name, 0)
  end
end

local function as_list(value)
  if value == nil then
    return {}
  end
  return type(value) == 'table' and value or { value }
end

local function load(spec)
  local target = spec.path and store.local_target(spec.name) or store.remote_target(spec.name)
  if not vim.uv.fs_stat(target) then
    return false
  end

  vim.cmd.packadd(spec.name)
  if spec.config == false then
    -- Explicitly load without automatic configuration.
  elseif spec.config then
    spec.config(spec.opts or {})
  else
    auto_config(spec)
  end
  spec.loaded = true
  return true
end

local function load_with_dependencies(state, spec)
  if spec.loaded then
    return true
  end
  for _, dependency_name in ipairs(spec.dependencies) do
    if not load_with_dependencies(state, state.registry[dependency_name]) then
      return false
    end
  end
  return load(spec)
end

---@param state table
function M.setup(state)
  for name in pairs(state.entries) do
    local spec = state.registry[name]
    for _, event_spec in ipairs(as_list(spec.event)) do
      local event, pattern = event_spec:match('^(%S+)%s+(.+)$')
      vim.api.nvim_create_autocmd(event or event_spec, {
        pattern = pattern,
        once = true,
        callback = function()
          load_with_dependencies(state, spec)
        end,
      })
    end
    for _, filetype in ipairs(as_list(spec.ft)) do
      vim.api.nvim_create_autocmd('FileType', {
        pattern = filetype,
        once = true,
        callback = function()
          load_with_dependencies(state, spec)
        end,
      })
    end
    if not spec.event and not spec.ft then
      load_with_dependencies(state, spec)
    end
  end
end

return M
