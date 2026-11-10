return function(test)
  local Commands = require('cli.commands')

  ---`:exists()` treats a shorter name as an abbreviation, so compare exact names.
  local function installed(name)
    return vim.api.nvim_get_commands({})[name] ~= nil
  end

  local function realpath(path)
    return assert(vim.uv.fs_realpath(path))
  end

  local function define(name, spec)
    return require('cli').define(name, spec)
  end

  ---Backend double that records the Context it was asked to run.
  local function recorder(seen, name)
    return function(context, task)
      seen[#seen + 1] = { backend = name, context = context }
      task:finish({ kind = 'exit', code = 0 })
    end
  end

  test('installs one command named after the tool and runs it in the current directory', function()
    local seen = {}
    local tool = define('brew', {
      executable = 'brew',
      backends = { terminal = recorder(seen, 'terminal') },
    })
    assert(installed('Brew'), 'the default command name derives from the tool name')
    vim.cmd('Brew list --json')
    assert(#seen == 1 and seen[1].backend == 'terminal', 'unrouted subcommands use the terminal')
    assert(seen[1].context.executable == 'brew')
    assert(vim.deep_equal(seen[1].context.argv, { 'list', '--json' }))
    assert(seen[1].context.cwd == vim.fn.getcwd())
    assert(seen[1].context.env == nil, 'no editor means no injected environment')

    assert(Commands.dispose('brew') ~= nil)
    assert(not installed('Brew'))
    assert(Commands.dispose('brew') == nil, 'disposing twice is not an error')
    assert(tool.name == 'brew')
  end)

  test('prepends preset arguments and routes on the complete argv', function()
    local seen, keys = {}, {}
    define('brew', {
      executable = 'brew',
      route_key = function(argv)
        keys[#keys + 1] = table.concat(argv, ' ')
        return 'probe'
      end,
      command = 'Brew',
      presets = {
        B = { argv = { 'list' }, desc = 'list packages' },
        Bs = { argv = { 'search' } },
      },
      routes = { probe = 'process' },
      backends = { process = recorder(seen, 'process') },
    })
    assert(installed('Brew') and installed('B') and installed('Bs'))

    vim.cmd('B install jq')
    assert(vim.deep_equal(seen[1].context.argv, { 'list', 'install', 'jq' }))
    assert(seen[1].context.raw_input == 'list install jq')
    assert(keys[1] == 'list install jq', 'routing sees the preset and the typed arguments')
    assert(vim.api.nvim_get_commands({}).B.definition == 'list packages')
    Commands.dispose('brew')
  end)

  test('resolves the working directory on every invocation', function()
    local original = vim.fn.getcwd()
    local first, second = vim.fn.tempname() .. '-a', vim.fn.tempname() .. '-b'
    vim.fn.mkdir(first, 'p')
    vim.fn.mkdir(second, 'p')
    local seen = {}
    define('brew', { executable = 'brew', backends = { terminal = recorder(seen, 'terminal') } })

    local ok, err = pcall(function()
      vim.cmd('cd ' .. vim.fn.fnameescape(first))
      vim.cmd('Brew read')
      vim.cmd('cd ' .. vim.fn.fnameescape(second))
      vim.cmd('Brew read')
    end)
    vim.cmd('cd ' .. vim.fn.fnameescape(original))
    Commands.dispose('brew')

    assert(ok, err)
    assert(
      realpath(seen[1].context.cwd) == realpath(first)
        and realpath(seen[2].context.cwd) == realpath(second),
      'cwd must follow :cd'
    )
  end)

  test('opens the editor bridge for a plain true, and only then', function()
    local tool = define('brew', { executable = 'brew', editor = true })
    assert(tool.editor ~= nil, 'true means the bridge defaults')
    assert(type(tool.editor:env().GIT_EDITOR) == 'string')
    Commands.dispose('brew')
    assert(tool.editor:active() == false)

    local off = define('brew', { executable = 'brew', editor = false })
    assert(off.editor == nil)
    Commands.dispose('brew')
  end)

  test('pins the directory when one is given', function()
    local original = vim.fn.getcwd()
    local pinned = vim.fn.tempname()
    vim.fn.mkdir(pinned, 'p')
    local seen = {}
    define('brew', {
      executable = 'brew',
      cwd = pinned,
      backends = { terminal = recorder(seen, 'terminal') },
    })

    local elsewhere = vim.fn.tempname()
    vim.fn.mkdir(elsewhere, 'p')
    local ok, err = pcall(function()
      vim.cmd('cd ' .. vim.fn.fnameescape(elsewhere))
      vim.cmd('Brew read')
    end)
    vim.cmd('cd ' .. vim.fn.fnameescape(original))
    Commands.dispose('brew')

    assert(ok, err)
    assert(realpath(seen[1].context.cwd) == realpath(pinned))
  end)

  test('builds one provider per directory and prepends preset arguments', function()
    local queries, factories = {}, {}
    define('brew', {
      executable = 'brew',
      presets = { B = { argv = { 'list' } } },
      completion = function(cwd)
        factories[#factories + 1] = cwd
        return function(query)
          queries[#queries + 1] = { cwd = cwd, tokens = vim.deepcopy(query.tokens) }
          return { 'alpha', 'beta' }
        end
      end,
    })

    assert(vim.deep_equal(vim.fn.getcompletion('B al', 'cmdline'), { 'alpha' }))
    assert(vim.deep_equal(queries[1].tokens, { 'list' }), 'preset arguments are tokens, not text')
    assert(realpath(queries[1].cwd) == realpath(vim.fn.getcwd()))

    vim.fn.getcompletion('B al', 'cmdline')
    assert(#factories == 1, 'the provider is built once per directory')
    Commands.dispose('brew')
  end)

  test('installs no completion when the factory is absent', function()
    define('brew', { executable = 'brew', completion = false })
    assert(vim.deep_equal(vim.fn.getcompletion('Brew al', 'cmdline'), {}))
    Commands.dispose('brew')
  end)

  test('refuses to take over a command someone else registered', function()
    local foreign = false
    vim.api.nvim_create_user_command('BrewProbe', function()
      foreign = true
    end, {})
    local ok, err = pcall(define, 'brew', {
      executable = 'brew',
      presets = { BrewProbe = {} },
      alias = { 'BrewOther' },
    })
    vim.cmd('BrewProbe')
    pcall(vim.api.nvim_del_user_command, 'BrewProbe')
    Commands.dispose('brew')

    assert(not ok, 'installing over a foreign command must fail')
    assert(
      tostring(err):find('cli.tool: command already exists: BrewProbe', 1, true),
      tostring(err)
    )
    assert(foreign, 'the other command must keep working')
    assert(not installed('BrewOther'), 'a failed install rolls its own commands back')
  end)

  test('names the command and adds aliases without spelling out empty tables', function()
    local seen = {}
    local tool = define('brew', {
      executable = 'brew',
      command = 'Br',
      alias = 'B',
      presets = { Ba = {} },
      backends = { terminal = recorder(seen, 'terminal') },
    })
    assert(installed('Br') and installed('B') and installed('Ba') and not installed('Brew'))
    assert(
      vim.deep_equal(tool.commands, { 'Br', 'B', 'Ba' }),
      'the main name stays first: ' .. vim.inspect(tool.commands)
    )

    vim.cmd('B list --json')
    assert(
      vim.deep_equal(seen[1].context.argv, { 'list', '--json' }),
      'an alias runs the same command'
    )
    vim.cmd('Br services')
    assert(vim.deep_equal(seen[2].context.argv, { 'services' }))
    Commands.dispose('brew')

    local ok, err = pcall(define, 'brew', {
      executable = 'brew',
      alias = { 'BrewOne', 'BrewTwo' },
    })
    assert(
      ok and installed('Brew') and installed('BrewOne') and installed('BrewTwo'),
      tostring(err)
    )
    Commands.dispose('brew')

    local repeating = pcall(define, 'brew', { executable = 'brew', alias = { 'Brew', 'Brew' } })
    assert(repeating, 'a repeated alias is redundant, not fatal')
    Commands.dispose('brew')
  end)

  test('rejects a misspelled option instead of ignoring it', function()
    local ok, err =
      pcall(define, 'brew', { executable = 'brew', alias = 'B', command = 'Brew', commnad = 'x' })
    assert(
      not ok and tostring(err):find('cli.tool: unknown option: commnad', 1, true),
      tostring(err)
    )
    local aliases = pcall(define, 'brew', { executable = 'brew', alias = 42 })
    assert(not aliases and not installed('Brew'))
    local blank = pcall(define, 'brew', { executable = 'brew', command = '' })
    assert(not blank)
    local factory, factory_err =
      pcall(define, 'brew', { executable = 'brew', completion = { cache_ttl = 1 } })
    assert(
      not factory and tostring(factory_err):find('cli.tool: completion must be a factory', 1, true),
      tostring(factory_err)
    )
    Commands.dispose('brew')
  end)

  test('rejects a tool without an executable and a malformed command table', function()
    local ok, err = pcall(define, 'nothing', {})
    assert(
      not ok and tostring(err):find('cli.tool: executable is required', 1, true),
      tostring(err)
    )

    local bad_argv, bad_argv_err = pcall(define, 'brew', {
      executable = 'brew',
      presets = { B = { argv = { 'list', 1 } } },
    })
    assert(
      not bad_argv and tostring(bad_argv_err):find('argv values must be strings', 1, true),
      tostring(bad_argv_err)
    )
    Commands.dispose('brew')
  end)
end
