local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(root)
local loader = require('pack.loader')
local spec = require('pack.spec')
assert(vim.env.PACK_TEST_HOME, 'Run through tests/pack.ts for isolated storage')
local store = require('pack.store')

local count = 0
local function fixture(name, source)
  local target = store.local_target(name)
  vim.fn.mkdir(target .. '/lua', 'p')
  if source then
    vim.fn.writefile(
      vim.split(source, '\n', { plain = true }),
      target .. '/lua/' .. name:gsub('%.nvim$', '') .. '.lua'
    )
  end
  return { path = target }
end

local function run(name, source, fields, expected_error)
  count = count + 1
  local user = vim.tbl_extend('force', fixture(name, source), fields or {})
  local state = spec.build({ user })
  local ok, err = pcall(loader.setup, state)
  if expected_error then
    assert(not ok, name .. ': expected failure')
    assert(tostring(err):find(expected_error, 1, true), tostring(err))
    assert(not state.registry[name].loaded)
  else
    assert(ok, tostring(err))
    assert(state.registry[name].loaded)
  end
end

local ok, err = xpcall(function()
  run(
    'pack_auto.nvim',
    'return {setup=function(o) assert(vim.deep_equal(o, {})); vim.g.pack_auto_calls=(vim.g.pack_auto_calls or 0)+1 end}'
  )
  assert(vim.g.pack_auto_calls == 1)
  run('pack_auto.nvim', nil) -- require cache retains the actual module table
  assert(vim.g.pack_auto_calls == 2)
  run(
    'pack_options',
    'return {setup=function(o) assert(o.answer==42) end}',
    { opts = { answer = 42 } }
  )
  run('pack_disabled', "error('must not load')", { config = false, opts = {} })
  assert(package.loaded.pack_disabled == nil)
  local configured = false
  local options = { answer = 42 }
  run('pack_custom', "error('must not load')", {
    opts = options,
    config = function(received)
      assert(rawequal(received, options))
      configured = true
    end,
  })
  assert(configured and package.loaded.pack_custom == nil)
  fixture('pack_entry', 'return {setup=function() vim.g.pack_entry=true end}')
  vim.cmd.packadd('pack_entry')
  run('pack_explicit', nil, { main = 'pack_entry' })
  assert(vim.g.pack_entry)
  run('pack_vimscript', nil)
  run('pack_self', 'return {}')
  run('pack_missing', nil, { opts = {} }, 'pack_missing')
  run('pack_missing_main', nil, { main = 'absent_pack_entry' }, 'pack_missing_main')
  run('pack_no_setup', 'return {}', { opts = {} }, 'has no setup function')
  run('pack_broken', "error('entry exploded')", nil, 'entry exploded')
  run('pack_nested', "require('absent_pack_dependency')", nil, 'absent_pack_dependency')
  run(
    'pack_setup_error',
    "return {setup=function() error('setup exploded') end}",
    nil,
    'setup exploded'
  )

  local dependency = fixture(
    'pack_dep',
    'return {setup=function() vim.g.pack_dep_calls=(vim.g.pack_dep_calls or 0)+1 end}'
  )
  local first =
    fixture('pack_first', 'return {setup=function() assert(vim.g.pack_dep_calls==1) end}')
  local second =
    fixture('pack_second', 'return {setup=function() assert(vim.g.pack_dep_calls==1) end}')
  first.deps = { dependency }
  second.deps = { dependency }
  loader.setup(spec.build({ first, second }))
  assert(vim.g.pack_dep_calls == 1)
  count = count + 1

  local merged = fixture(
    'pack_merged',
    [[return {setup=function(o)
    assert(o.behavior.enabled and o.menu.border=='rounded')
    assert(vim.g.pack_dep_calls==2)
    vim.g.pack_merged_calls=(vim.g.pack_merged_calls or 0)+1
  end}]]
  )
  local merged_state = spec.build({
    vim.tbl_extend('force', merged, { opts = { behavior = { enabled = true } } }),
    vim.tbl_extend('force', merged, {
      opts = { menu = { border = 'rounded' } },
      deps = { dependency },
    }),
  })
  loader.setup(merged_state)
  assert(vim.g.pack_merged_calls == 1)
  count = count + 1

  local lazy = fixture('pack_lazy', nil)
  lazy.event = 'User PackRetry'
  local attempts = 0
  lazy.config = function()
    attempts = attempts + 1
    if attempts == 1 then
      error('retry me')
    end
  end
  local lazy_state = spec.build({ lazy })
  loader.setup(lazy_state)
  pcall(vim.api.nvim_exec_autocmds, 'User', { pattern = 'PackRetry' })
  vim.api.nvim_exec_autocmds('User', { pattern = 'PackRetry' })
  assert(attempts == 2 and lazy_state.registry.pack_lazy.loaded, 'failed load must retry')
  vim.api.nvim_exec_autocmds('User', { pattern = 'PackRetry' })
  assert(attempts == 2)

  local stale = fixture('pack_stale', nil)
  stale.event = 'User PackStale'
  stale.config = function()
    error('stale setup callback ran')
  end
  loader.setup(spec.build({ stale }))
  loader.setup(spec.build({}))
  vim.api.nvim_exec_autocmds('User', { pattern = 'PackStale' })
  local reentrant = fixture('pack_reentrant', nil)
  reentrant.event = 'User PackReentrant'
  local calls = 0
  reentrant.config = function()
    calls = calls + 1
    local callback = vim.api.nvim_get_autocmds({ group = 'PackLoader' })[1].callback
    assert(type(callback) == 'function')
    callback()
  end
  loader.setup(spec.build({ reentrant }))
  vim.api.nvim_exec_autocmds('User', { pattern = 'PackReentrant' })
  assert(calls == 1, 'configuration must not reenter')
  local missing_name = 'pack_late'
  local late_calls = 0
  local late_state = spec.build({
    {
      path = store.local_target(missing_name),
      event = { 'User PackLate', 'User PackOther' },
      config = function()
        late_calls = late_calls + 1
      end,
    },
  })
  loader.setup(late_state)
  vim.api.nvim_exec_autocmds('User', { pattern = 'PackLate' })
  assert(late_calls == 0 and not late_state.registry[missing_name].loaded)
  fixture(missing_name)
  vim.api.nvim_exec_autocmds('User', { pattern = 'PackLate' })
  vim.api.nvim_exec_autocmds('User', { pattern = 'PackOther' })
  assert(late_calls == 1)

  local parent = fixture('pack_retry_parent')
  parent.event = 'User PackDependency'
  local dep_attempts, parent_calls = 0, 0
  local retry_dep = fixture('pack_retry_dep')
  retry_dep.config = function()
    dep_attempts = dep_attempts + 1
    if dep_attempts == 1 then
      error('dependency retry')
    end
  end
  parent.deps = { retry_dep }
  parent.config = function()
    parent_calls = parent_calls + 1
  end
  loader.setup(spec.build({ parent }))
  pcall(vim.api.nvim_exec_autocmds, 'User', { pattern = 'PackDependency' })
  assert(parent_calls == 0)
  vim.api.nvim_exec_autocmds('User', { pattern = 'PackDependency' })
  assert(parent_calls == 1 and dep_attempts == 2)
  count = count + 6
end, debug.traceback)
assert(ok, err)
print(('Pack setup: %d cases passed'):format(count))
