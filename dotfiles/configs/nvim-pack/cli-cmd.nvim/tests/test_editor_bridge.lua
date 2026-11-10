return function(test)
  local EditorBridge = require('cli-cmd.bridge.editor')

  test('exposes a quoted editor command that points at an existing config', function()
    local bridge = EditorBridge.new({ open = function() end })
    local env = bridge:env()
    assert(env.GIT_EDITOR == env.GIT_SEQUENCE_EDITOR)
    assert(env.GIT_EDITOR:find(vim.v.progpath, 1, true), 'editor command must use this Neovim')
    assert(
      env.GIT_EDITOR:find(' %-n ', 1) ~= nil,
      'editor must not create a swap file for the file Git passes as an argument'
    )
    local config = env.GIT_EDITOR:match("%-u '([^']+)'")
    assert(config and vim.fn.filereadable(config) == 1, 'config file must exist')
    assert(not bridge:active())
    bridge:dispose()
    assert(vim.fn.filereadable(config) == 0, 'dispose must remove the config file')
  end)

  test(
    'blocks real Git, keeps :write from finishing, and continues after the session closes',
    function()
      local root = cli_cmd_test.temp_repo()
      cli_cmd_test.stage(root, 'tracked.txt', { 'changed' })
      local opened = {}
      local bridge = EditorBridge.new({
        cwd = root,
        open = function(path)
          vim.cmd('split ' .. vim.fn.fnameescape(path))
          opened.buf = vim.api.nvim_get_current_buf()
          opened.win = vim.api.nvim_get_current_win()
          opened.path = path
        end,
      })
      local git = vim.system({ 'git', 'commit' }, { cwd = root, text = true, env = bridge:env() })

      vim.wait(15000, function()
        return bridge:active()
      end, 10)
      assert(bridge:active(), 'editor session was never opened')
      assert(
        opened.path:find('COMMIT_EDITMSG', 1, true),
        'Git must request the commit message file'
      )
      assert(not git:is_closing(), 'git must stay blocked while editing')

      vim.api.nvim_buf_set_lines(opened.buf, 0, -1, false, { 'bridged message' })
      vim.api.nvim_buf_call(opened.buf, function()
        vim.cmd('silent write')
      end)
      vim.wait(500, function()
        return false
      end, 10)
      assert(not git:is_closing(), ':write alone must not release git')

      vim.api.nvim_win_close(opened.win, true)
      local completed = git:wait(15000)
      assert(
        completed and completed.code == 0,
        'git did not continue after the session closed: '
          .. tostring(completed and completed.stderr)
      )
      assert(not bridge:active())
      local subject = cli_cmd_test.ok(root, { 'git', 'log', '-1', '--pretty=%s' }).stdout
      assert(subject:find('bridged message', 1, true), 'commit did not use the bridged message')
      bridge:dispose()
    end
  )

  test('cancelling the session makes the real Git command fail', function()
    local root = cli_cmd_test.temp_repo()
    cli_cmd_test.stage(root, 'tracked.txt', { 'second change' })
    local bridge = EditorBridge.new({ cwd = root })
    local git = vim.system({ 'git', 'commit' }, { cwd = root, text = true, env = bridge:env() })

    vim.wait(15000, function()
      return bridge:active()
    end, 10)
    assert(bridge:active())
    assert(bridge:cancel() == 1)

    local completed = git:wait(15000)
    assert(completed, 'git did not exit after cancellation')
    assert(completed.code ~= 0, 'cancelled edit must fail the git command')
    local log = cli_cmd_test.run(root, { 'git', 'log', '-1', '--pretty=%s' })
    assert(not log.stdout:find('second change', 1, true), 'cancelled commit must not be created')
    bridge:dispose()
  end)

  ---The child's config and the script it loads, read the way the child would.
  local function child_config(bridge)
    local config = bridge:env().GIT_EDITOR:match("%-u '([^']+)'")
    return table.concat(vim.fn.readfile(config), '\n'), config
  end

  test('keeps the child config to one line and the script on disk', function()
    local bridge = EditorBridge.new({ layout = 'tab' })
    local config, path = child_config(bridge)
    local script = config:match('^dofile%("(.-)"%)$')
    assert(script, 'the config must only load the external editor script: ' .. config)
    assert(loadfile(script), 'the external editor script must compile on its own')
    assert(#vim.fn.readfile(path) == 1, 'the child config must stay one line')
    assert(vim.fn.filereadable(script) == 1, 'the script must exist: ' .. script)
    bridge:dispose()
  end)

  test('releases an abandoned external editor instead of blocking it forever', function()
    local bridge = EditorBridge.new({ layout = 'tab' })
    local config = child_config(bridge)
    local body = table.concat(vim.fn.readfile(config:match('^dofile%("(.-)"%)$')), '\n')
    assert(
      body:find('vim.rpcnotify', 1, true),
      'the external editor must not block on a request it cannot abandon'
    )
    assert(
      body:find('nvim_eval', 1, true),
      'the external editor must notice when this instance goes away'
    )
    assert(
      body:find('vim.wait', 1, true),
      'the external editor must keep an event loop so notifications run'
    )
    bridge:dispose()
  end)

  test('cancels pending edit sessions when Neovim is about to exit', function()
    local opened = 0
    local bridge = EditorBridge.new({
      open = function(path)
        opened = opened + 1
        vim.cmd('tabnew ' .. vim.fn.fnameescape(path))
      end,
    })
    assert(bridge:_serve(vim.fn.tempname() .. '.txt', vim.fn.tempname()))
    assert(bridge:active(), 'a session must be pending')
    vim.cmd('doautocmd VimLeavePre')
    assert(not bridge:active(), 'VimLeavePre must release every pending session')
    assert(opened == 1)
    bridge:dispose()
  end)

  test('opens a commit message in a new tab when configured', function()
    local root = cli_cmd_test.temp_repo()
    cli_cmd_test.stage(root, 'tracked.txt', { 'tab layout' })
    local tabs_before = #vim.api.nvim_list_tabpages()
    local bridge = EditorBridge.new({ cwd = root, layout = 'tab' })
    local git = vim.system({ 'git', 'commit' }, { cwd = root, text = true, env = bridge:env() })

    vim.wait(15000, function()
      return bridge:active()
    end, 10)
    assert(bridge:active())
    assert(#vim.api.nvim_list_tabpages() == tabs_before + 1, 'tab layout must open a new tab')
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'tab message' })
    vim.api.nvim_buf_call(buf, function()
      vim.cmd('silent write')
    end)
    vim.api.nvim_win_close(win, true)
    local completed = git:wait(15000)
    assert(completed and completed.code == 0, 'git must continue after the tab closes')
    assert(#vim.api.nvim_list_tabpages() == tabs_before, 'closing the session must close its tab')
    local subject = cli_cmd_test.ok(root, { 'git', 'log', '-1', '--pretty=%s' }).stdout
    assert(subject:find('tab message', 1, true))
    bridge:dispose()
  end)

  test('supports vertical splits and rejects unknown layouts', function()
    -- A non-existent editor socket keeps the session from signalling this instance.
    local bridge = EditorBridge.new({ layout = 'vsplit' })
    assert(bridge:_serve('/tmp/cli-vsplit-probe.txt', vim.fn.tempname()))
    local layout = vim.fn.winlayout()
    assert(layout[1] == 'row', 'vsplit layout must be a row: ' .. vim.inspect(layout))
    assert(bridge:cancel() == 1)

    ---@diagnostic disable-next-line: assign-type-mismatch
    local ok, err = pcall(EditorBridge.new, { layout = 'float' })
    assert(not ok)
    assert(tostring(err):find('layout must be one of', 1, true))
  end)

  test('lets a custom open function override the layout', function()
    local seen
    local bridge = EditorBridge.new({
      layout = 'tab',
      open = function(path)
        seen = path
      end,
    })
    assert(bridge:_serve('/tmp/cli-custom-open.txt', vim.fn.tempname()))
    assert(seen == '/tmp/cli-custom-open.txt')
    bridge:dispose()
  end)

  test('rejects construction without a server', function()
    local ok, err = pcall(EditorBridge.new, { server = '' })
    assert(not ok)
    assert(tostring(err):find('cli-cmd.bridge.editor:', 1, true))
  end)
end
