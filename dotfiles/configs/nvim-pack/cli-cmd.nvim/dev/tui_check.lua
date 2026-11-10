-- Real-TTY smoke harness. Not part of the plugin runtime.
-- Usage (inside a real terminal Neovim):
--   :luafile .../cli-cmd.nvim/dev/tui_check.lua
--   :lua _G.cli_tui.dump('/tmp/cli-tui.json')
--   :lua _G.cli_tui.teardown()
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:append(root)

-- Drop cached modules so editing the plugin and re-sourcing this file takes effect.
for name in pairs(package.loaded) do
  if name == 'cli-cmd' or name:match('^cli%-cmd%.') then
    package.loaded[name] = nil
  end
end

local Installer = require('cli-cmd.install')
local cli = require('cli-cmd')

local cwd = vim.fn.getcwd()
local notes = {}
local original_notify = vim.notify

---@diagnostic disable-next-line: duplicate-set-field
vim.notify = function(msg, level, opts)
  notes[#notes + 1] = { msg = tostring(msg), level = level }
  return original_notify(msg, level, opts)
end

local tool = cli.install('git', { command = 'MyGit', editor = { layout = 'tab' } })

_G.cli_tui = {
  tool = tool,
  notes = notes,
  notify = original_notify,
  teardown = function()
    vim.notify = original_notify
    Installer.dispose('git')
    _G.cli_tui = nil
  end,
  ---Snapshot observable state. Terminals are opaque, so this records what the
  ---TUI actually shows instead of guessing.
  dump = function(path)
    local tabs = vim.api.nvim_list_tabpages()
    local tab_info = {}
    for index, tab in ipairs(tabs) do
      local current = vim.api.nvim_tabpage_get_win(tab)
      local buffer = vim.api.nvim_win_get_buf(current)
      tab_info[index] = {
        buf = vim.api.nvim_buf_get_name(buffer),
        filetype = vim.bo[buffer].filetype,
        lines = vim.api.nvim_buf_get_lines(buffer, 0, 3, false),
      }
    end
    local snapshot = {
      cwd = cwd,
      hidden = vim.o.hidden,
      tty = vim.fn.executable('tty') == 1,
      tabs = #tabs,
      tab_info = tab_info,
      notes = notes,
      buffers = vim.tbl_map(function(buffer)
        return { name = vim.api.nvim_buf_get_name(buffer), mod = vim.bo[buffer].modified }
      end, vim.api.nvim_list_bufs()),
      commits = vim.fn.systemlist({ 'git', 'log', '--format=%s' }),
      hooks = (function()
        local path = vim.fn.getcwd() .. '/.git/COMMIT_EDITMSG'
        return vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {}
      end)(),
      screen = vim.fn.execute('messages'),
    }
    vim.fn.writefile({ vim.json.encode(snapshot) }, path)
  end,
}

vim.notify('cli-cmd.nvim TUI harness ready', vim.log.levels.INFO)
