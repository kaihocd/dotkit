return function(test)
  test('builds a Git command definition and routes native command arguments', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    local seen
    local command = _G.cli_cmd_test.git_command({
      cwd = vim.fn.getcwd(),
      backends = {
        process = function(context, task)
          seen = context
          task:complete({ kind = 'exit', code = 0 })
        end,
      },
      routes = { capture = 'process' },
      fallback = 'process',
    })
    command:register('CliGitProbe', { route_key = GitCommand.route_key })
    vim.cmd([[execute 'CliGitProbe --no-pager -C . status']])
    assert(seen.executable == 'git')
    assert(vim.deep_equal(seen.argv, { '--no-pager', '-C', '.', 'status' }))
    assert(seen.route_key == 'capture')
  end)

  test('preserves custom executable and environment configuration', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    local command = _G.cli_cmd_test.git_command({
      executable = '/usr/bin/git',
      cwd = vim.fn.getcwd(),
      env = { GIT_OPTIONAL_LOCKS = '0' },
      backends = {
        process = function(context, task)
          assert(context.executable == '/usr/bin/git')
          assert(context.env.GIT_OPTIONAL_LOCKS == '0')
          task:complete({ kind = 'exit', code = 0 })
        end,
      },
      routes = { capture = 'process' },
      fallback = 'process',
    })
    command:register('CliGitConfigProbe', { route_key = GitCommand.route_key })
    vim.cmd('CliGitConfigProbe status')
  end)

  test('combines the editor environment with an env function that returns nothing', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    local Command = require('cli-cmd.command')
    local seen
    local command = _G.cli_cmd_test.git_command({
      cwd = vim.fn.getcwd(),
      editor = {
        env = function()
          return { GIT_EDITOR = 'editor' }
        end,
      },
      -- An env function is allowed to return nothing; the editor variables must
      -- still arrive, and the function itself must never be treated as a table.
      env = function()
        return nil
      end,
      backends = {
        process = function(context, task)
          seen = context
          task:complete({ kind = 'exit', code = 0 })
        end,
      },
      routes = { capture = 'process' },
      fallback = 'process',
    })
    assert(command ~= nil)
    command:dispatch({ argv = { 'commit' }, route_key = 'capture' })
    assert(seen.env.GIT_EDITOR == 'editor', vim.inspect(seen.env))
  end)

  test(
    'runs real Git through the default preset: short reports notify, long ones open a tab',
    function()
      local GitCommand = require('cli-cmd.tools.git.command')
      local Task = require('cli-cmd.task')
      local repo = _G.cli_cmd_test.temp_repo()
      _G.cli_cmd_test.stage(repo, 'tracked.txt', { 'first' })

      local messages = {}
      local presenter = require('cli-cmd.presenter.output').new({
        notify = function(message, level)
          messages[#messages + 1] = { message = message, level = level }
        end,
      })
      local git = _G.cli_cmd_test.git_command({ cwd = repo, presenter = presenter })

      local tabs_before = #vim.api.nvim_list_tabpages()
      local status = git:dispatch({
        argv = { 'status', '--short', '--branch' },
        route_key = GitCommand.route_key({ 'status' }),
      })
      vim.wait(10000, function()
        return status:status() == 'finished'
      end, 20)
      assert(status:result().kind == 'exit' and status:result().code == 0)
      assert(#vim.api.nvim_list_tabpages() == tabs_before, 'status must not open a terminal')
      assert(#messages == 1, vim.inspect(messages))
      assert(messages[1].message:find('## ', 1, true), messages[1].message)

      local log = git:dispatch({
        argv = { 'log', '-1', '--oneline' },
        route_key = GitCommand.route_key({ 'log' }),
      })
      vim.wait(10000, function()
        return log:status() == 'finished'
      end, 20)
      assert(log:result().kind == 'exit' and log:result().code == 0)
      assert(
        #vim.api.nvim_list_tabpages() == tabs_before,
        'a one-line log still fits the message area'
      )
      assert(#messages == 2, vim.inspect(messages))
      assert(messages[2].message:find('init', 1, true), messages[2].message)

      -- Same subcommand, longer report: nothing is notified, a tab carries it.
      for index = 1, 16 do
        local name = string.format('n%02d.txt', index)
        _G.cli_cmd_test.stage(repo, name, { name })
        _G.cli_cmd_test.ok(repo, { 'git', 'commit', '--quiet', '-m', name })
      end
      local long = git:dispatch({
        argv = { 'log', '--oneline' },
        route_key = GitCommand.route_key({ 'log' }),
      })
      vim.wait(10000, function()
        return long:status() == 'finished'
      end, 20)
      assert(long:result().kind == 'exit' and long:result().code == 0)
      assert(#vim.api.nvim_list_tabpages() == tabs_before + 1, 'a long log belongs in a tab')
      assert(#messages == 2, 'a long report must not also flood the message area')
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert(#lines == 17, vim.inspect(lines))
      assert(lines[1]:find('n16.txt', 1, true), lines[1])
      vim.cmd('tabclose!')
    end
  )

  test('requires a working directory and keeps Git errors namespaced', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    local ok, err = pcall(_G.cli_cmd_test.git_command, {})
    assert(not ok)
    assert(tostring(err):find('cli-cmd.tools.git.command:', 1, true))
  end)
end
