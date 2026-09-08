local M = {}

local function normalize(user_spec)
  assert(
    (user_spec.path == nil) ~= (user_spec.src == nil),
    'Plugin spec must define exactly one of path or src'
  )
  if user_spec.path then
    assert(
      user_spec.path:sub(1, 1) == '/',
      'Local plugin path must be absolute: ' .. user_spec.path
    )
  end

  local name = user_spec.name or vim.fs.basename(user_spec.path or user_spec.src)
  assert(name and name ~= '', 'Plugin spec requires a name')
  return vim.tbl_extend('force', user_spec, {
    dependencies = {},
    loaded = false,
    name = name,
  })
end

local function register(state, user_spec, is_entry, visiting)
  local spec = normalize(user_spec)
  assert(not visiting[spec.name], 'Circular plugin dependency: ' .. spec.name)

  local existing = state.registry[spec.name]
  if existing then
    assert(
      existing.path == spec.path and existing.src == spec.src,
      'Duplicate plugin name: ' .. spec.name
    )
    if is_entry then
      state.entries[spec.name] = true
    end
    return existing
  end

  state.registry[spec.name] = spec
  visiting[spec.name] = true
  if is_entry then
    state.entries[spec.name] = true
  end
  for _, dependency in ipairs(user_spec.deps or {}) do
    local dependency_spec = register(state, dependency, false, visiting)
    table.insert(spec.dependencies, dependency_spec.name)
  end
  visiting[spec.name] = nil
  return spec
end

---@param user_specs? table[]
---@return table
function M.build(user_specs)
  local state = { entries = {}, registry = {} }
  for _, user_spec in ipairs(user_specs or {}) do
    register(state, user_spec, true, {})
  end
  return state
end

---@param state table
---@return string[]
function M.names(state)
  local result = {}
  for name in pairs(state.registry) do
    table.insert(result, name)
  end
  table.sort(result)
  return result
end

---@param state table
---@param selected_names? string[]
---@return table[]
function M.select(state, selected_names)
  selected_names = selected_names or {}
  if #selected_names == 0 then
    selected_names = M.names(state)
  end

  local result = {}
  local seen = {}
  local visiting = {}
  local function append(name)
    local selected = state.registry[name]
    assert(selected, 'Unknown plugin: ' .. name)
    assert(not visiting[name], 'Circular plugin dependency: ' .. name)
    if seen[name] then
      return
    end

    visiting[name] = true
    for _, dependency_name in ipairs(selected.dependencies) do
      append(dependency_name)
    end
    visiting[name] = nil
    seen[name] = true
    table.insert(result, selected)
  end

  for _, name in ipairs(selected_names) do
    append(name)
  end
  return result
end

return M
