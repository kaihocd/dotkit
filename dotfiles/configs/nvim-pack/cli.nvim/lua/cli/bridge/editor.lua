---Editor bridge: opens a file requested by an external process (for example
---`GIT_EDITOR`) in the current Neovim instance.
---
---The external editor is a short-lived headless Neovim started with `-u <config>`.
---It asks this instance over RPC to open the file, stays alive so Git keeps
---waiting, and exits only when notified: `quitall!` when the edit session ends,
---`cquit <status>` when it fails, so Git always sees a real editor exit code.
---Nothing here blocks the current Neovim event loop.
local check = require('cli.guard')('cli.editor_bridge')

---One bridge instance. Each holds its own external-editor config, its own RPC
---registry entry and its own edit sessions; bridges never share state.
---@class cli.EditorBridge
---@field private _id string
---@field private _server string
---@field private _config string
---@field private _cwd string
---@field private _open fun(path: string)
---@field private _sequence integer
---@field private _sessions table<integer, table>
---@field private _leave_group? integer
---@field private _disposed boolean
local EditorBridge = {}
EditorBridge.__index = EditorBridge

local sequence = 0

---Single-quote a value for the shell Git uses to read `GIT_EDITOR`.
local function shell_quote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

---The external editor script ships next to this module and is loaded with
---`dofile`: the child runs `--clean`, so it has no runtimepath to `require` from.
---Derived from this file's own path, so it works from any install location.
local function serve_script()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return vim.fn.fnamemodify(source, ':p:h') .. '/serve.lua'
end

---The child's config is one line: everything the script needs arrives in the
---environment, so no value is ever spliced into Lua source.
local function config_lines()
  return { 'dofile(' .. string.format('%q', serve_script()) .. ')' }
end

---`-n` matters: Git passes the edited file as an argument, so without it the
---external editor opens a second buffer for a file this instance holds and warns
---(`W325`) into the command output.
local function editor_command(config)
  return table.concat({
    shell_quote(vim.v.progpath),
    '--clean',
    '--headless',
    '-n',
    '-i',
    'NONE',
    '-u',
    shell_quote(config),
  }, ' ')
end

local layouts = {
  split = function(path)
    vim.cmd('split ' .. vim.fn.fnameescape(path))
  end,
  vsplit = function(path)
    vim.cmd('vsplit ' .. vim.fn.fnameescape(path))
  end,
  tab = function(path)
    vim.cmd('tabnew ' .. vim.fn.fnameescape(path))
  end,
}

---Default session presentation: open the file in a split of the current tab.
---@param path string
function EditorBridge.default_open(path)
  layouts.split(path)
end

---Release the external editor process. `status == 0` continues it, any other
---status makes it fail, which is how a cancelled edit aborts the command.
---@param editor_socket string
---@param status integer
local function notify(editor_socket, status)
  local connected, channel = pcall(vim.fn.sockconnect, 'pipe', editor_socket, { rpc = true })
  if not (connected and channel ~= 0) then
    return false
  end
  local command = status == 0 and 'quitall!' or ('cquit ' .. status)
  return pcall(vim.rpcnotify, channel, 'nvim_exec2', command, {})
end

---@param opts? {cwd?: string, layout?: 'split'|'vsplit'|'tab', open?: fun(path: string), server?: string}
---@return cli.EditorBridge
function EditorBridge.new(opts)
  opts = opts or {}
  check(type(opts) == 'table', 'options must be a table')
  local server = opts.server or vim.v.servername
  check(
    type(server) == 'string' and server ~= '',
    'Neovim server is required; start one with serverstart()'
  )
  local open = opts.open
  if open == nil then
    local layout = opts.layout or 'split'
    check(
      type(layout) == 'string' and layouts[layout] ~= nil,
      'layout must be one of split, vsplit, tab (or pass open)'
    )
    open = layouts[layout]
  end
  check(type(open) == 'function', 'open must be a function')

  sequence = sequence + 1
  local id = 'cli_editor_' .. sequence
  local bridge = setmetatable({
    _id = id,
    _server = server,
    _cwd = opts.cwd or vim.fn.getcwd(),
    _open = open,
    _config = vim.fn.tempname() .. '.lua',
    _sessions = {},
    _sequence = 0,
    _disposed = false,
  }, EditorBridge)
  vim.fn.writefile(config_lines(), bridge._config)
  _G.__cli_editor_bridge = _G.__cli_editor_bridge or {}
  _G.__cli_editor_bridge[id] = function(path, editor_socket)
    return bridge:_serve(path, editor_socket)
  end
  -- Quitting Neovim with a pending session would otherwise abandon the external
  -- process: Git keeps waiting on an editor whose owner is gone.
  bridge._leave_group = vim.api.nvim_create_augroup('cli_editor_bridge_' .. id, { clear = true })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = bridge._leave_group,
    callback = function()
      bridge:cancel(130)
    end,
  })
  return bridge
end

---Environment that makes an external process use this instance as its editor.
---The child needs `-u`'s config only; which bridge to talk to travels in the
---environment, next to the editor command itself.
---@return table<string, string>
function EditorBridge:env()
  check(not self._disposed, 'bridge is disposed')
  local editor = editor_command(self._config)
  return {
    GIT_EDITOR = editor,
    GIT_SEQUENCE_EDITOR = editor,
    CLI_EDITOR_ID = self._id,
    CLI_EDITOR_SERVER = self._server,
  }
end

---Whether any edit session is still waiting for the user.
---@return boolean
function EditorBridge:active()
  return next(self._sessions) ~= nil
end

---Open a requested file and keep the external process blocked until the session
---finishes. Called from the external editor over RPC.
---@param path string
---@param editor_socket string
---@return boolean
function EditorBridge:_serve(path, editor_socket)
  if self._disposed then
    notify(editor_socket, 1)
    return false
  end
  check(type(path) == 'string' and path ~= '', 'edited path is required')
  check(type(editor_socket) == 'string' and editor_socket ~= '', 'editor socket is required')

  self._sequence = self._sequence + 1
  local session = { id = self._sequence, path = path, editor_socket = editor_socket }
  self._sessions[session.id] = session

  local opened, open_error = pcall(self._open, path)
  if not opened then
    self._sessions[session.id] = nil
    notify(editor_socket, 1)
    error('cli.editor_bridge: failed to open ' .. path .. ': ' .. tostring(open_error), 0)
  end
  session.buf = vim.api.nvim_get_current_buf()
  session.win = vim.api.nvim_get_current_win()
  session.augroup = vim.api.nvim_create_augroup(self._id .. '_' .. session.id, { clear = true })
  vim.api.nvim_create_autocmd({ 'WinClosed', 'BufDelete', 'BufWipeout' }, {
    group = session.augroup,
    nested = true,
    callback = function(data)
      local closed = (data.event == 'WinClosed' and tonumber(data.match) == session.win)
        or data.buf == session.buf
      if closed then
        self:_finish(session, 0)
      end
    end,
  })
  return true
end

---Release the external process. `status == 0` continues it, any other status
---makes it fail, which is how a cancelled edit aborts the command.
---@param session table
---@param status integer
---@return boolean
function EditorBridge:_finish(session, status)
  if not self._sessions[session.id] then
    return false
  end
  self._sessions[session.id] = nil

  pcall(vim.api.nvim_del_augroup_by_id, session.augroup)
  notify(session.editor_socket, status)
  if session.win and vim.api.nvim_win_is_valid(session.win) then
    pcall(vim.api.nvim_win_close, session.win, true)
  end
  if session.buf and vim.api.nvim_buf_is_valid(session.buf) then
    pcall(vim.api.nvim_buf_delete, session.buf, { force = true })
  end
  return true
end

---Cancel every pending session so the external process fails.
---@param status? integer
---@return integer cancelled
function EditorBridge:cancel(status)
  status = status or 1
  check(type(status) == 'number' and status > 0, 'cancel status must be positive')
  local cancelled = 0
  for _, session in pairs(vim.deepcopy(self._sessions)) do
    if self:_finish(session, status) then
      cancelled = cancelled + 1
    end
  end
  return cancelled
end

---Release pending sessions and remove this bridge's temporary state.
function EditorBridge:dispose()
  if self._disposed then
    return
  end
  self:cancel(1)
  self._disposed = true
  pcall(os.remove, self._config)
  if self._leave_group then
    pcall(vim.api.nvim_del_augroup_by_id, self._leave_group)
    self._leave_group = nil
  end
  if _G.__cli_editor_bridge then
    _G.__cli_editor_bridge[self._id] = nil
  end
end

return EditorBridge
