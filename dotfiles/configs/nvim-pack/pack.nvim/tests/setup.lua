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
end, debug.traceback)
assert(ok, err)
print(('Pack setup: %d cases passed'):format(count))
