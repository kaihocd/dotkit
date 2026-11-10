---The external editor `cli-cmd.bridge.editor` starts.
---
---It runs in its own `--clean --headless` Neovim, so it cannot `require` anything
---from this plugin: `dofile` loads it, `CLI_EDITOR_ID` and `CLI_EDITOR_SERVER`
---tell it which instance to talk to, and `argv(0)` is the file to edit.
local id = vim.env.CLI_EDITOR_ID
local server = vim.env.CLI_EDITOR_SERVER

---`cquit` normally ends the process; `os.exit` is the guarantee, so callers
---never have to write `return` after a failure.
local function fail()
  vim.cmd('cquit 1')
  os.exit(1)
end

if id == nil or id == '' or server == nil or server == '' then
  fail()
end

local connected, channel = pcall(vim.fn.sockconnect, 'pipe', server, { rpc = true })
if not connected or channel == 0 then
  fail()
end

---Ask the owning instance to open this file. This is a notification, not a
---request: this process must never wait for an answer it cannot abandon. Git
---stays blocked because this process stays alive.
local sent = pcall(
  vim.rpcnotify,
  channel,
  'nvim_exec_lua',
  string.format(
    'return _G.__cli_editor_bridge[%q](%s, %s)',
    id,
    vim.inspect(vim.fn.argv(0)),
    vim.inspect(vim.v.servername)
  ),
  {}
)
if not sent then
  fail()
end

---A closed channel means the edit can never finish, so release Git instead of
---blocking forever. A ping is the portable liveness check: channel info does not
---report a closed channel.
while true do
  vim.wait(500)
  if not pcall(vim.rpcnotify, channel, 'nvim_eval', '0') then
    fail()
  end
end
