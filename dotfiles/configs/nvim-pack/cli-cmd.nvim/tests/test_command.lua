return function(test)
  test('builds an isolated command dispatcher from backend definitions', function()
    local Command = require('cli-cmd.command')
    local seen
    local command = Command.new({
      executable = 'tool',
      cwd = '/work',
      backends = {
        inspect = function(context, task)
          seen = { context = context, task = task }
          task:complete({ kind = 'exit', code = 0 })
        end,
        terminal = function(_, task)
          task:complete({ kind = 'delegated', target = 'terminal' })
        end,
      },
      routes = { inspect = 'inspect' },
      fallback = 'terminal',
    })
    local args = { 'status' }
    local task = command:dispatch({ argv = args, route_key = 'inspect' })
    args[1] = 'changed'
    assert(seen.context.executable == 'tool')
    assert(seen.context.cwd == '/work')
    assert(seen.context.argv[1] == 'status')
    assert(seen.task == task)
    assert(task:result().kind == 'exit')
  end)

  test(
    'provides native process and terminal backends without requiring external plugins',
    function()
      local Command = require('cli-cmd.command')
      local command = Command.new({ executable = 'sh', cwd = vim.fn.getcwd() })
      local task = command:dispatch({
        argv = { '-c', 'printf command-layer' },
        route_key = 'process',
      })
      vim.wait(3000, function()
        return task:status() == 'finished'
      end, 10)
      assert(task:result().kind == 'exit' and task:result().code == 0)
    end
  )

  test('opens terminal routes in a native tab and honours terminal_layout', function()
    local Command = require('cli-cmd.command')
    local command = Command.new({ executable = 'sh', cwd = vim.fn.getcwd() })
    local tabs_before = #vim.api.nvim_list_tabpages()
    local task = command:dispatch({
      argv = { '-c', 'printf routed' },
      route_key = 'terminal',
    })
    vim.wait(5000, function()
      return task:status() == 'finished'
    end, 10)
    assert(task:result().kind == 'exit' and task:result().code == 0)
    assert(#vim.api.nvim_list_tabpages() == tabs_before + 1, 'terminal route must open a tab')
    vim.cmd('tabclose!')

    local split_command =
      Command.new({ executable = 'sh', cwd = vim.fn.getcwd(), terminal_layout = 'split' })
    local split_task = split_command:dispatch({
      argv = { '-c', 'printf routed' },
      route_key = 'terminal',
    })
    vim.wait(5000, function()
      return split_task:status() == 'finished'
    end, 10)
    assert(#vim.api.nvim_list_tabpages() == tabs_before, 'terminal_layout=split must not add a tab')
    vim.api.nvim_win_close(0, true)
  end)

  test('rejects an unknown terminal_layout', function()
    local Command = require('cli-cmd.command')
    local ok, err = pcall(Command.new, {
      executable = 'sh',
      cwd = vim.fn.getcwd(),
      terminal_layout = 'float',
    })
    assert(not ok)
    assert(tostring(err):find('terminal_layout must be one of', 1, true))
  end)

  test('rejects invalid command definitions with command errors', function()
    local Command = require('cli-cmd.command')
    local ok, err = pcall(Command.new, { executable = 'tool' })
    assert(not ok)
    assert(tostring(err):find('cli-cmd.command:', 1, true))
  end)

  test('registers a native command and forwards fargs without reparsing', function()
    local Command = require('cli-cmd.command')
    local seen
    local command = Command.new({
      executable = 'tool',
      cwd = vim.fn.getcwd(),
      backends = {
        process = function(context, task)
          seen = context
          task:complete({ kind = 'exit', code = 0 })
        end,
      },
      routes = { inspect = 'process' },
      fallback = 'process',
    })
    command:register('CliRegistrationProbe', { route_key = 'inspect' })
    vim.cmd([[execute 'CliRegistrationProbe my\ file.txt "hello world"']])
    assert(vim.deep_equal(seen.argv, { 'my file.txt', '"hello', 'world"' }))
    assert(seen.route_key == 'inspect')
  end)

  test('accepts a route function and completion callback', function()
    local Command = require('cli-cmd.command')
    local command = Command.new({ executable = 'tool', cwd = vim.fn.getcwd() })
    local completion = function()
      return { 'one' }
    end
    command:register('CliRegistrationComplete', {
      route_key = function(args)
        return args[1]
      end,
      complete = completion,
    })
    assert(vim.api.nvim_get_commands({})['CliRegistrationComplete'] ~= nil)
  end)

  test('uses the command-level completion and allows forced re-registration', function()
    local Command = require('cli-cmd.command')
    local command = Command.new({
      executable = 'tool',
      cwd = vim.fn.getcwd(),
      complete = function()
        return { 'from-command' }
      end,
    })
    command:register('CliRegistrationDefault', { route_key = 'status' })
    assert(not pcall(command.register, command, 'CliRegistrationDefault', { route_key = 'status' }))
    command:register('CliRegistrationDefault', { route_key = 'status', force = true })
    assert(
      vim.deep_equal(vim.fn.getcompletion('CliRegistrationDefault ', 'cmdline'), { 'from-command' })
    )
  end)

  test('rejects invalid registration options', function()
    local Command = require('cli-cmd.command')
    local command = Command.new({ executable = 'tool', cwd = vim.fn.getcwd() })
    local ok, err = pcall(command.register, command, 'CliBad', { complete = 42 })
    assert(not ok)
    assert(tostring(err):find('cli-cmd.command:', 1, true))
  end)
end
