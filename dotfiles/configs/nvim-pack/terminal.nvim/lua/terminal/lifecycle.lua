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
---@param opts? { name?: string, cwd?: string }
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

  local ok, job_id = pcall(vim.api.nvim_buf_call, buf, function()
    return vim.fn.jobstart(cfg.shell, {
      term = true,
      cwd = cwd,
    })
  end)

  if not ok or type(job_id) ~= 'number' or job_id <= 0 then
    vim.api.nvim_buf_delete(buf, { force = true })
    error('terminal: failed to start shell: ' .. tostring(job_id))
  end

  local index = state.add({
    buf = buf,
    name = name,
    cwd = cwd,
    job_id = job_id,
  })

  keymaps.setup_term(buf, api)
  M.attach_close_autocmd(buf, api)

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

  -- Detach the record before jobstop: its eventual TermClose is idempotent.
  api.on_term_close(term.buf)
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

return M
