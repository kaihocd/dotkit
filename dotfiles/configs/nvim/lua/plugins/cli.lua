---@type pack.UserSpec
return {
  path = vim.fs.joinpath(G.local_plugins_root, 'cli.nvim'),
  event = 'UIEnter',
  config = function()
    local app = require('cli').setup({
      cwd = vim.fn.getcwd(),
      completion = false,
      editor = { layout = 'tab' },
    })
    local Git = require('cli.adapter.git')

    -- Both dispatch and completion answer "which directory?" at the moment they
    -- run, so `:G` follows `:cd` and window-local directories instead of the
    -- directory Neovim happened to start in. One provider per directory keeps
    -- the provider's memoized Git lookups without rebuilding them per keystroke.
    local completions = {}
    local function complete(arglead, cmdline, cursorpos)
      local cwd = vim.fn.getcwd()
      completions[cwd] = completions[cwd] or require('cli.completion.git').callback({ cwd = cwd })
      return completions[cwd](arglead, cmdline, cursorpos)
    end

    vim.api.nvim_create_user_command('G', function(command)
      app.command:dispatch({
        argv = command.fargs,
        raw_input = command.args,
        route_key = Git.route_key(command.fargs),
        cwd = vim.fn.getcwd(),
      })
    end, {
      nargs = '*',
      complete = complete,
      desc = 'Run Git',
    })
  end,
}
