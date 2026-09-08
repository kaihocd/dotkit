local spec_module = require('pack.spec')
local store = require('pack.store')

local M = {}

local function remote_registry()
  local result = {}
  -- get() calls lock_sync(), which can install/remove plugins. Read the native
  -- lock for side-effect-free status/clean previews; mutations use vim.pack.
  local path = vim.fs.joinpath(vim.fn.stdpath('config'), 'nvim-pack-lock.json')
  if vim.fn.filereadable(path) == 0 then return result end
  local lock = vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
  assert(type(lock.plugins) == 'table', 'Invalid vim.pack lockfile: ' .. path)
  for name, entry in pairs(lock.plugins) do
    result[name] = { spec = { name = name, src = entry.src }, path = store.remote_target(name) }
  end
  return result
end

local function unknown_targets()
  local unknown = {}
  for _, item in ipairs({
    { root = vim.fs.dirname(store.remote_target('_')), known = remote_registry() },
    { root = vim.fs.dirname(store.local_target('_')), known = store.read_ownership('local') },
  }) do
    if vim.uv.fs_stat(item.root) then
      for name in vim.fs.dir(item.root) do
        if not item.known[name] then
          table.insert(unknown, vim.fs.joinpath(item.root, name))
        end
      end
    end
  end
  table.sort(unknown)
  return unknown
end

local function matches_remote(plugin, spec)
  return plugin and plugin.spec.src == spec.src
    and plugin.path == store.remote_target(spec.name)
end

local function build(spec)
  if spec.build then
    spec.build({
      name = spec.name,
      path = spec.path or store.remote_target(spec.name),
      source = spec.path or spec.src,
    })
  end
end

local function sync_local(spec)
  local source = spec.path
  local source_stat = vim.uv.fs_stat(source)
  assert(
    source_stat and source_stat.type == 'directory',
    'Local plugin source is not a directory: ' .. source
  )

  local target = store.local_target(spec.name)
  local created = false
  if not store.is_expected_link(target, source) then
    assert(not vim.uv.fs_lstat(target), 'Local plugin target is occupied: ' .. target)
    vim.fn.mkdir(vim.fs.dirname(target), 'p')
    local linked, error_message = vim.uv.fs_symlink(source, target)
    if not linked and not store.is_expected_link(target, source) then
      error('Unable to link local plugin: ' .. tostring(error_message))
    end
    created = true
  end

  local ownership = store.read_ownership('local')
  ownership[spec.name] = source
  store.write_ownership('local', ownership)
  if created then
    build(spec)
  end
end

---@param state table
---@param selected_names? string[]
function M.sync(state, selected_names)
  local remote = {}
  for _, spec in ipairs(spec_module.select(state, selected_names)) do
    if spec.path then
      sync_local(spec)
    else
      table.insert(remote, { src = spec.src, name = spec.name, version = spec.version })
    end
  end

  if #remote == 0 then
    return
  end

  local function revision(name)
    local target = store.remote_target(name)
    if not vim.uv.fs_stat(target) then
      return nil
    end
    local result = vim.system({ 'git', '-C', target, 'rev-parse', 'HEAD' }, { text = true }):wait()
    assert(result.code == 0, 'Unable to read Git revision for plugin: ' .. name)
    return vim.trim(result.stdout)
  end

  local managed = remote_registry()
  local before = {}
  local update = {}
  for _, remote_spec in ipairs(remote) do
    local target_exists = vim.uv.fs_lstat(store.remote_target(remote_spec.name)) ~= nil
    local plugin = managed[remote_spec.name]
    assert(not plugin or matches_remote(plugin, remote_spec),
      'Git plugin source/path conflicts with vim.pack: ' .. remote_spec.name)
    if target_exists then
      assert(matches_remote(plugin, remote_spec),
        'Git plugin target is not managed by vim.pack: ' .. remote_spec.name)
      table.insert(update, remote_spec.name)
    end
    before[remote_spec.name] = revision(remote_spec.name)
  end

  vim.pack.add(remote, { confirm = false, load = false })
  if #update > 0 then
    vim.pack.update(update, { force = true })
  end

  for _, remote_spec in ipairs(remote) do
    if before[remote_spec.name] ~= revision(remote_spec.name) then
      build(state.registry[remote_spec.name])
    end
  end
end

---@param state table
---@param selected_names? string[]
function M.build(state, selected_names)
  for _, spec in ipairs(spec_module.select(state, selected_names)) do
    build(spec)
  end
end

local function stale_local(state)
  local stale = {}
  for name, source in pairs(store.read_ownership('local')) do
    if not state.registry[name] then
      table.insert(stale, { name = name, source = source, target = store.local_target(name) })
    end
  end
  table.sort(stale, function(left, right)
    return left.name < right.name
  end)
  return stale
end

local function stale_remote(state)
  local stale = {}
  for name in pairs(remote_registry()) do
    if not state.registry[name] then
      table.insert(stale, name)
    end
  end
  table.sort(stale)
  return stale
end

---@param state table
---@param apply boolean
function M.clean(state, apply)
  local local_plugins = stale_local(state)
  local remote_plugins = stale_remote(state)
  local unknown = unknown_targets()
  local result = { local_plugins = local_plugins, remote_plugins = remote_plugins, unknown = unknown }
  if not apply then return result end
  -- Native lock_sync can adopt unknown directories. Refuse mutation until
  -- these have been reviewed so a later clean cannot silently delete them.
  assert(#unknown == 0, 'Unmanaged paths found; run PackClean and review them before cleaning')

  local ownership = store.read_ownership('local')
  for _, plugin in ipairs(local_plugins) do
    if store.is_expected_link(plugin.target, plugin.source) then
      assert(vim.uv.fs_unlink(plugin.target))
      ownership[plugin.name] = nil
    end
  end
  store.write_ownership('local', ownership)
  if #remote_plugins > 0 then
    -- Keep native protection for plugins active in this session.
    vim.pack.del(remote_plugins)
  end
  return result
end

---@param state table
---@return table
function M.status(state)
  local managed = remote_registry()
  local result = { loaded = {}, waiting = {}, missing = {}, stale = {}, conflict = {}, unknown = unknown_targets() }
  for _, name in ipairs(spec_module.names(state)) do
    local spec = state.registry[name]
    local target = spec.path and store.local_target(name) or store.remote_target(name)
    local target_stat = vim.uv.fs_lstat(target)
    if spec.loaded then
      table.insert(result.loaded, name)
    elseif not target_stat then
      table.insert(result.missing, name)
    elseif spec.path and not store.is_expected_link(target, spec.path) then
      table.insert(result.conflict, name)
    elseif spec.src and not matches_remote(managed[name], spec) then
      table.insert(result.conflict, name)
    else
      table.insert(result.waiting, name)
    end
  end
  for name in pairs(store.read_ownership('local')) do
    if not state.registry[name] then
      table.insert(result.stale, name)
    end
  end
  for _, name in ipairs(stale_remote(state)) do
    table.insert(result.stale, name)
  end
  table.sort(result.stale)
  return result
end

return M
