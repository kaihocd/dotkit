return function(test)
  test('registers a native command and forwards fargs without reparsing', function()
    local Command = require('cli.command')
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
    assert(seen.raw_input == [[my\ file.txt "hello world"]])
    assert(seen.route_key == 'inspect')
  end)

  test('accepts a route function and completion callback', function()
    local Command = require('cli.command')
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
    local Command = require('cli.command')
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
    local Command = require('cli.command')
    local command = Command.new({ executable = 'tool', cwd = vim.fn.getcwd() })
    local ok, err = pcall(command.register, command, 'CliBad', { complete = 42 })
    assert(not ok)
    assert(tostring(err):find('cli.command:', 1, true))
  end)
end
