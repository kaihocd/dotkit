---@type pack.UserSpec
return {
  path = vim.fs.joinpath(G.local_plugins_root, 'cli-cmd.nvim'),
  event = 'UIEnter',
  -- The interactive surface is the terminal manager, so it is configured first.
  deps = { { path = vim.fs.joinpath(G.local_plugins_root, 'terminal.nvim') } },
  config = function()
    local terminal = require('terminal')
    local cli = require('cli-cmd')

    -- Run a command that needs a terminal as a session in terminal.nvim's popup,
    -- and report the exit code terminal.nvim sees instead of claiming nothing.
    local function in_terminal(context, task)
      local index = terminal.new({
        command = { context.executable, unpack(context.argv) },
        cwd = context.cwd,
        env = context.env,
        name = table.concat({ context.executable, unpack(context.argv) }, ' '),
        on_exit = function(code)
          task:finish({ kind = 'exit', code = code })
        end,
      })
      terminal.open()
      terminal.select(index)
      task:annotate('surface', 'terminal')
      return { owns_result = true }
    end

    cli.install('git', { alias = 'G', terminal_capability = { delegate = in_terminal } })
    cli.install('palette')
    cli.install('brew', { terminal_capability = { delegate = in_terminal } })
  end,
}
