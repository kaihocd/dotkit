return function(test)
  local Tool = require('cli-cmd.tool')

  local function fails(pattern, fn)
    local ok, err = pcall(fn)
    assert(not ok, 'expected a failure')
    assert(tostring(err):find(pattern, 1, true), tostring(err))
  end

  test('names the main command after the tool, capitalising only its first letter', function()
    local _, order = Tool.names({ name = 'brew' })
    assert(vim.deep_equal(order, { 'Brew' }))
    _, order = Tool.names({ name = 'git-lfs' })
    assert(vim.deep_equal(order, { 'Git-lfs' }))
    _, order = Tool.names({ name = 'brew', command = 'B' })
    assert(vim.deep_equal(order, { 'B' }), 'an explicit command name wins')
  end)

  test('accepts one alias or a list, and drops redundant repeats', function()
    local entries, order = Tool.names({ name = 'brew', alias = 'B' })
    assert(vim.deep_equal(order, { 'Brew', 'B' }))
    assert(vim.deep_equal(entries.B, {}), 'an alias starts with no preset arguments')
    _, order = Tool.names({ name = 'brew', alias = { 'B', 'Brew', 'Br' } })
    assert(vim.deep_equal(order, { 'Brew', 'B', 'Br' }), 'order is kept, repeats are dropped')
    fails('alias must be a string or a list', function()
      Tool.names({ name = 'brew', alias = { B = 'x' } })
    end)
    fails('command names must be non-empty strings', function()
      Tool.names({ name = 'brew', alias = { '' } })
    end)
  end)

  test('registers presets after every fixed name, sorted, with their arguments', function()
    local entries, order = Tool.names({
      name = 'brew',
      alias = 'B',
      presets = {
        Bs = { argv = { 'search' }, desc = 'search' },
        Ba = { argv = { 'list' } },
        B = { argv = { 'list', '--formula' } },
      },
    })
    assert(vim.deep_equal(order, { 'Brew', 'B', 'Ba', 'Bs' }), vim.inspect(order))
    assert(
      vim.deep_equal(entries.B, { argv = { 'list', '--formula' } }),
      'a preset may refine an alias'
    )
    assert(entries.Bs.desc == 'search')
  end)

  test('rejects presets that are not a name-to-entry map', function()
    fails('presets must be a table', function()
      ---@diagnostic disable-next-line: assign-type-mismatch
      Tool.names({ name = 'brew', presets = { { argv = { 'list' } } } })
    end)
    fails('command entries must be tables: Bl', function()
      ---@diagnostic disable-next-line: assign-type-mismatch
      Tool.names({ name = 'brew', presets = { Bl = 'list' } })
    end)
    fails('argv values must be strings: Bl', function()
      ---@diagnostic disable-next-line: assign-type-mismatch
      Tool.names({ name = 'brew', presets = { Bl = { argv = { 'list', 1 } } } })
    end)
    fails('desc must be a string: Bl', function()
      ---@diagnostic disable-next-line: assign-type-mismatch
      Tool.names({ name = 'brew', presets = { Bl = { desc = 1 } } })
    end)
  end)

  test('validation rejects what cannot be installed, before anything is created', function()
    local before = vim.api.nvim_get_commands({})
    Tool.validate({ name = 'brew', executable = 'brew' })
    local spec =
      { name = 'brew', executable = 'brew', alias = 'B', presets = { Bl = { argv = { 'list' } } } }
    local snapshot = vim.deepcopy(spec)
    Tool.validate(spec)
    assert(vim.deep_equal(before, vim.api.nvim_get_commands({})), 'validating creates nothing')
    assert(vim.deep_equal(spec, snapshot), 'the caller table is not rewritten')
  end)

  test(
    'validation demands identity, known options, and an executable unless a builder exists',
    function()
      fails('name is required', function()
        ---@diagnostic disable-next-line: missing-fields
        Tool.validate({ executable = 'brew' })
      end)
      fails('spec must be a table', function()
        ---@diagnostic disable-next-line: param-type-mismatch, missing-fields
        Tool.validate({ 'brew' })
      end)
      fails('unknown option: commnad', function()
        Tool.validate({ name = 'brew', executable = 'brew', commnad = 'Brew' })
      end)
      fails('executable is required', function()
        ---@diagnostic disable-next-line: missing-fields
        Tool.validate({ name = 'brew' })
      end)
      ---@diagnostic disable-next-line: missing-return
      Tool.validate({ name = 'brew', build = function() end })
      fails('build must be a function', function()
        ---@diagnostic disable-next-line: assign-type-mismatch
        Tool.validate({ name = 'brew', executable = 'brew', build = {} })
      end)
      fails('route_key must be a function', function()
        ---@diagnostic disable-next-line: assign-type-mismatch
        Tool.validate({ name = 'brew', executable = 'brew', route_key = 'list' })
      end)
      fails('cwd must be a string', function()
        ---@diagnostic disable-next-line: assign-type-mismatch
        Tool.validate({ name = 'brew', executable = 'brew', cwd = 1 })
      end)
      fails('completion must be a factory (fun(cwd): provider) or false', function()
        ---@diagnostic disable-next-line: assign-type-mismatch
        Tool.validate({ name = 'brew', executable = 'brew', completion = { cache_ttl = 1 } })
      end)
      ---@diagnostic disable-next-line: assign-type-mismatch
      Tool.validate({ name = 'brew', executable = 'brew', completion = false })
    end
  )
end
