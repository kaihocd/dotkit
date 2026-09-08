local highlights = require('palette.highlights')
local palette = require('palette.palette')

local M = {}

---@type uv.uv_fs_event_t?
local watcher = nil
---@type uv.uv_timer_t?
local reload_timer = nil
---@type string?
local last_contents = nil
local started = false
local reload_pending = false

---@param message unknown
local function report_error(message)
  vim.notify(tostring(message), vim.log.levels.ERROR, {
    title = 'Palette',
  })
end

local function reload()
  reload_pending = false

  local loaded, theme, contents = pcall(palette.load)
  if not loaded then
    report_error(theme)
    return
  end

  if contents == last_contents then
    return
  end

  local applied, apply_error = pcall(highlights.apply, theme)
  if not applied then
    report_error(apply_error)
    return
  end

  last_contents = contents
end

local function schedule_reload()
  if reload_pending or not started then
    return
  end

  reload_pending = true
  vim.schedule(reload)
end

local function debounce_reload()
  if not reload_timer then
    return
  end

  reload_timer:stop()
  reload_timer:start(75, 0, vim.schedule_wrap(schedule_reload))
end

local function stop()
  started = false
  reload_pending = false

  if watcher then
    watcher:stop()
    watcher:close()
    watcher = nil
  end

  if reload_timer then
    reload_timer:stop()
    reload_timer:close()
    reload_timer = nil
  end
end

function M.setup()
  if started then
    return
  end

  local directory = palette.directory()
  local directory_stat, stat_error, stat_code = vim.uv.fs_stat(directory)
  if not directory_stat then
    if stat_code == 'ENOENT' then
      return
    end

    error('Failed to inspect Palette state: ' .. tostring(stat_error), 0)
  end

  watcher = assert(vim.uv.new_fs_event())
  reload_timer = assert(vim.uv.new_timer())
  local watched, watch_error = watcher:start(directory, {}, debounce_reload)
  if not watched then
    stop()
    error('Failed to watch Palette state: ' .. tostring(watch_error), 0)
  end

  started = true
  schedule_reload()

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('UiPalette', { clear = true }),
    callback = stop,
  })
end

return M
