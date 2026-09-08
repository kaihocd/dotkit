local spec = require('pack.spec')

local M = {}

local function report_status(status)
  for _, kind in ipairs({ 'loaded', 'waiting', 'missing', 'stale', 'conflict', 'unknown' }) do
    for _, name in ipairs(status[kind]) do
      vim.notify(string.format('%-7s  %s', kind, name))
    end
  end
end

local function report_clean(result)
  for _, path in ipairs(result.unknown) do
    vim.notify('Unmanaged (not removed): ' .. path, vim.log.levels.WARN)
  end
  if #result.local_plugins + #result.remote_plugins + #result.unknown == 0 then
    vim.notify('Nothing to clean')
  end
  for _, plugin in ipairs(result.local_plugins) do
    vim.notify('Would unlink local plugin: ' .. plugin.name)
  end
  for _, name in ipairs(result.remote_plugins) do
    vim.notify('Would remove Git plugin: ' .. name)
  end
end

---@param pack table
---@param state table
function M.setup(pack, state)
  local function complete_names()
    return spec.names(state)
  end

  vim.api.nvim_create_user_command('PackStatus', function()
    local status = pack.status()
    if not next(state.registry) and #status.stale == 0 and #status.unknown == 0 then
      vim.notify('No plugins declared')
      return
    end
    report_status(status)
  end, {})

  vim.api.nvim_create_user_command('PackSync', function(command)
    if not next(state.registry) then
      vim.notify('No plugins declared')
      return
    end
    pack.sync(command.fargs)
  end, { nargs = '*', complete = complete_names })

  vim.api.nvim_create_user_command('PackBuild', function(command)
    if not next(state.registry) then
      vim.notify('No plugins declared')
      return
    end
    pack.build(command.fargs)
  end, { nargs = '*', complete = complete_names })

  vim.api.nvim_create_user_command('PackClean', function(command)
    local result = pack.clean(command.bang)
    if not command.bang then
      report_clean(result)
    end
  end, { bang = true })
end

return M
