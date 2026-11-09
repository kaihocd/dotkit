return function(test)
  local function facade(opts)
    return require('cli').setup(opts)
  end

  test('assembles a working Git command without an editor or an implicit registration', function()
    local app = facade({ cwd = vim.fn.getcwd() })
    assert(vim.fn.exists(':CliFacadeImplicit') == 0)
    assert(app.command ~= nil and type(app.command.dispatch) == 'function')
    assert(app.editor == nil, 'the editor bridge must stay off by default')
    assert(app.presenter ~= nil and type(app.presenter.attach) == 'function')
    assert(type(app.completion) == 'function')
    app.dispose()
  end)

  test('defaults cwd to the current directory and rejects unknown adapters', function()
    local app = facade()
    assert(app.cwd == vim.fn.getcwd())
    app.dispose()

    local ok, err = pcall(facade, { cwd = vim.fn.getcwd(), adapter = 'pnpm' })
    assert(not ok and err:find('cli: unknown adapter: pnpm', 1, true), tostring(err))
  end)

  test('forwards the routing preset and route overrides to the command', function()
    local targets = {}
    local function recorder(name)
      return function(_, task)
        targets[#targets + 1] = name
        task:complete({ kind = 'exit', code = 0 })
      end
    end
    local app = facade({
      cwd = vim.fn.getcwd(),
      routes = { log = 'process' },
      backends = { process = recorder('process'), terminal = recorder('terminal') },
    })
    local function dispatch(argv, route_key)
      app.command:dispatch({
        argv = argv,
        raw_input = table.concat(argv, ' '),
        route_key = route_key,
      })
    end
    dispatch({ 'status' }, 'status')
    dispatch({ 'log' }, 'log')
    dispatch({ 'rebase' }, 'rebase')
    assert(vim.deep_equal(targets, { 'process', 'process', 'terminal' }), vim.inspect(targets))
    app.dispose()
  end)

  test('honours replace_routes so the preset can be dropped entirely', function()
    local targets = {}
    local app = facade({
      cwd = vim.fn.getcwd(),
      replace_routes = true,
      routes = { status = 'terminal' },
      backends = {
        process = function(_, task)
          targets[#targets + 1] = 'process'
          task:complete({ kind = 'exit', code = 0 })
        end,
        terminal = function(_, task)
          targets[#targets + 1] = 'terminal'
          task:complete({ kind = 'exit', code = 0 })
        end,
      },
    })
    app.command:dispatch({ argv = { 'status' }, raw_input = 'status', route_key = 'status' })
    app.command:dispatch({ argv = { 'log' }, raw_input = 'log', route_key = 'log' })
    assert(vim.deep_equal(targets, { 'terminal', 'terminal' }), vim.inspect(targets))
    app.dispose()
  end)

  test('injects the editor bridge only when asked, and disposes it', function()
    local seen
    local app = facade({
      cwd = vim.fn.getcwd(),
      editor = { layout = 'tab', server = vim.fn.tempname() },
      backends = {
        process = function(context, task)
          seen = context
          task:complete({ kind = 'exit', code = 0 })
        end,
      },
    })
    assert(app.editor ~= nil)
    app.command:dispatch({ argv = { 'commit' }, raw_input = 'commit', route_key = 'commit' })
    assert(type(seen.env.GIT_EDITOR) == 'string' and seen.env.GIT_EDITOR ~= '')
    assert(seen.env.GIT_SEQUENCE_EDITOR == seen.env.GIT_EDITOR)
    app.dispose()
    assert(app.editor:active() == false)

    local plain_seen
    local plain = facade({
      cwd = vim.fn.getcwd(),
      backends = {
        process = function(context, task)
          plain_seen = context
          task:complete({ kind = 'exit', code = 0 })
        end,
      },
    })
    plain.command:dispatch({ argv = { 'commit' }, raw_input = 'commit', route_key = 'commit' })
    assert(plain_seen.env == nil or plain_seen.env.GIT_EDITOR == nil)
    plain.dispose()
  end)

  test('respects completion = false and presenter = false', function()
    local app = facade({ cwd = vim.fn.getcwd(), completion = false, presenter = false })
    assert(app.completion == nil)
    assert(app.presenter == false)
    app.register('CliFacadeQuiet')
    assert(vim.fn.exists(':CliFacadeQuiet') == 2)
    app.dispose()
    assert(vim.fn.exists(':CliFacadeQuiet') == 0, 'dispose must remove registered commands')
  end)

  test('register fills in the route key and dispose removes every command it made', function()
    local Git = require('cli.adapter.git')
    local seen
    local app = facade({
      cwd = vim.fn.getcwd(),
      routes = { status = 'process' },
      backends = {
        process = function(context, task)
          seen = context
          task:complete({ kind = 'exit', code = 0 })
        end,
      },
    })
    app.register('CliFacadeProbe')
    app.register('CliFacadeProbeTwo', { bang = true })
    assert(vim.fn.exists(':CliFacadeProbe') == 2)
    assert(vim.fn.exists(':CliFacadeProbeTwo') == 2)
    vim.cmd('CliFacadeProbe --no-pager status')
    assert(seen.route_key == 'status')
    assert(Git.route_key(seen.argv) == 'status')
    app.dispose()
    app.dispose()
    assert(vim.fn.exists(':CliFacadeProbe') == 0)
    assert(vim.fn.exists(':CliFacadeProbeTwo') == 0)
  end)

  test('runs real Git through the assembled command', function()
    local repo = _G.cli_test.temp_repo()
    _G.cli_test.stage(repo, 'staged.txt', { 'content' })
    local chunks = {}
    local collector = {
      attach = function(_, task)
        task:on(function(event)
          if event.kind == 'output' then
            chunks[#chunks + 1] = event.data
          end
        end)
      end,
    }
    local app = facade({ cwd = repo, presenter = collector })
    local task = app.command:dispatch({
      argv = { 'status', '--porcelain' },
      raw_input = 'status --porcelain',
      route_key = 'status',
    })
    vim.wait(10000, function()
      return task:status() == 'finished'
    end, 10)
    local result = task:result()
    assert(result.kind == 'exit' and result.code == 0, vim.inspect(result))
    local output = table.concat(chunks, '')
    assert(output:find('staged.txt', 1, true), 'expected status output, got: ' .. output)
    app.dispose()
  end)
end
