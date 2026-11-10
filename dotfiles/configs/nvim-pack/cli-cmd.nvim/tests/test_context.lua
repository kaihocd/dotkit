return function(test)
  test('preserves parsed argv and adapter route without interpreting Git options', function()
    local context = require('cli-cmd.context')
    local input = {
      executable = 'git',
      argv = { '-C', 'a directory', '--no-pager', 'commit', '-m', 'hello world' },
      cwd = vim.fn.getcwd(),
      env = { GIT_EDITOR = 'editor' },
      route_key = 'commit',
    }
    assert(vim.deep_equal(context.new(input), input))
  end)

  test('accepts native escaped spaces and preserves native quote behavior', function()
    local received
    vim.api.nvim_create_user_command('CliContextProbe', function(opts)
      received = require('cli-cmd.context').new({
        executable = 'git',
        argv = opts.fargs,
        cwd = vim.fn.getcwd(),
      })
    end, { nargs = '*' })
    local ok, err = pcall(function()
      vim.cmd([[CliContextProbe add my\ file.txt]])
      assert(vim.deep_equal(received.argv, { 'add', 'my file.txt' }))
      assert(received.route_key == nil)
      vim.cmd([[CliContextProbe commit -m "hello world"]])
      assert(vim.deep_equal(received.argv, { 'commit', '-m', '"hello', 'world"' }))
    end)
    vim.api.nvim_del_user_command('CliContextProbe')
    assert(ok, err)
  end)

  test('isolates argv and env from caller mutations without modifying editor state', function()
    local cwd = vim.fn.getcwd()
    local input = {
      executable = 'tool',
      argv = { '', '$HOME', '$(echo unsafe)', '*', '|', 'a\nb' },
      cwd = cwd,
      env = { CLI_CONTEXT_TEST = 'local' },
    }
    local first = require('cli-cmd.context').new(input)
    local second = require('cli-cmd.context').new(input)
    assert(vim.deep_equal(first.argv, input.argv))
    input.argv[1], input.env.CLI_CONTEXT_TEST = 'changed', 'changed'
    assert(first.argv[1] == '' and first.env.CLI_CONTEXT_TEST == 'local')
    first.argv[2] = 'changed'
    assert(second.argv[2] == '$HOME')
    assert(vim.fn.getcwd() == cwd)
    assert(vim.env.CLI_CONTEXT_TEST ~= 'local')
  end)

  test('rejects malformed input before execution', function()
    local context = require('cli-cmd.context')
    local function rejects(field, value)
      local input = { executable = 'git', argv = {}, cwd = vim.fn.getcwd() }
      input[field] = value
      local ok, err = pcall(context.new, input)
      assert(not ok, 'accepted invalid ' .. field .. ': ' .. vim.inspect(value))
      assert(tostring(err):find('cli-cmd.context:', 1, true), tostring(err))
    end
    rejects('executable', '')
    rejects('executable', 'git\0bad')
    rejects('executable', false)
    rejects('argv', 'status')
    rejects('argv', { 'status', false })
    rejects('argv', { [2] = 'status' })
    rejects('argv', { option = 'status' })
    rejects('argv', { 'a\0b' })
    rejects('cwd', '')
    rejects('cwd', 'a\0b')
    rejects('env', false)
    rejects('env', { ['A=B'] = 'value' })
    rejects('env', { [''] = 'value' })
    rejects('env', { A = false })
    rejects('env', { A = 'a\0b' })
    rejects('route_key', false)
    rejects('route_key', '')
    local ok = pcall(context.new, nil)
    assert(not ok)
  end)
end
