local config = require('terminal.config')
local keymaps = require('terminal.keymaps')
local state = require('terminal.state')
local util = require('terminal.util')

-- Terminal buffer and job lifecycle.
local M = {}

-- Attach the terminal job close handler for a terminal buffer.
---@param buf integer
---@param api table
function M.attach_close_autocmd(buf, api)
  vim.api.nvim_create_autocmd('TermClose', {
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(function()
        api.on_term_close(buf)
      end)
    end,
  })
end

-- Create a terminal buffer, start its job, and register it in state.
---@param opts? { name?: string, cwd?: string, command?: string[], env?: table<string, string>, keep?: boolean, on_exit?: fun(code: integer) }
---@param api table
---@return integer index
---@return integer buf
function M.create(opts, api)
  opts = opts or {}

  local cfg = config.get()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('buflisted', false, { buf = buf })

  local cwd = opts.cwd or vim.fn.getcwd()
  local name = opts.name or cfg.default_term_name
  -- A command session runs argv directly; only a plain session starts a shell.
  local spawn = opts.command or cfg.shell
  -- A command is one-shot and its output is the result, so it stays listed after
  -- it exits. A shell that exited is gone, which is the behaviour it always had.
  local keep = opts.keep
  if keep == nil then
    keep = opts.command ~= nil
  end

  local ok, job_id = pcall(vim.api.nvim_buf_call, buf, function()
    return vim.fn.jobstart(spawn, {
      term = true,
      cwd = cwd,
      env = opts.env,
      on_exit = function(_, code)
        -- Neovim reports the exit after TermClose, so this cannot be the removal
        -- decision; it only records what the job said.
        vim.schedule(function()
          api.on_term_exit(buf, code)
          if opts.on_exit then
            opts.on_exit(code)
          end
        end)
      end,
    })
  end)

  if not ok or type(job_id) ~= 'number' or job_id <= 0 then
    vim.api.nvim_buf_delete(buf, { force = true })
    error(
      'terminal: failed to start '
        .. (opts.command and 'command' or 'shell')
        .. ': '
        .. tostring(job_id)
    )
  end

  local bound, failure = pcall(function()
    keymaps.setup_term(buf, api)
    M.attach_close_autocmd(buf, api)
  end)
  if not bound then
    pcall(vim.fn.jobstop, job_id)
    vim.api.nvim_buf_delete(buf, { force = true })
    error(failure, 0)
  end

  local index = state.add({
    buf = buf,
    name = name,
    cwd = cwd,
    job_id = job_id,
    command = opts.command,
    keep = keep,
  })

  return index, buf
end

-- Ensure there is always at least one terminal record.
---@param api table
function M.ensure_one(api)
  if state.count() == 0 then
    M.create(nil, api)
  end
end

-- Rename a terminal record by index.
---@param index integer
---@param name string
function M.rename(index, name)
  local term = state.terminals[index]
  if not term then
    return
  end

  term.name = name
end

-- Stop the terminal job, falling back to direct cleanup if needed.
---@param index integer
---@param api table
function M.stop_or_remove(index, api)
  local term = state.terminals[index]
  if not term then
    return
  end

  -- Remove the record before jobstop: its eventual TermClose is idempotent, and a
  -- kept session would otherwise refuse to go away.
  api.forget(term.buf)
  pcall(vim.fn.jobstop, term.job_id)
end

-- Remove a closed terminal record from state.
---@param buf integer
---@return terminal.record? removed
function M.remove_closed(buf)
  if util.is_exiting() then
    return nil
  end

  local removed = state.remove_by_buf(buf)

  return removed
end

-- Detach records before stopping jobs so delayed exit callbacks cannot revive them.
function M.shutdown()
  local terminals = state.terminals
  state.terminals = {}
  state.current_index = 1
  for _, term in ipairs(terminals) do
    pcall(vim.fn.jobstop, term.job_id)
    if vim.api.nvim_buf_is_valid(term.buf) then
      vim.api.nvim_buf_delete(term.buf, { force = true })
    end
  end
  for _, buf in ipairs({ state.list_buf, state.help_buf }) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  state.list_buf, state.help_buf = nil, nil
end

return M
