local store = require('pack.store')

local M = {}

local function as_list(value)
  if value == nil then
    return {}
  end
  return type(value) == 'table' and value or { value }
end

local function load(state, spec)
  local target = spec.path and store.local_target(spec.name) or store.remote_target(spec.name)
  if not vim.uv.fs_stat(target) then
    return false
  end

  vim.cmd.packadd(spec.name)
  if spec.config then
    spec.config(spec.opts or {})
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
  return load(state, spec)
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
