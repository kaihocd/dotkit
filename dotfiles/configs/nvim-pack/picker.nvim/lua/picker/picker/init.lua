local PickerPanel = require('picker.picker.panel')
local backend = require('picker.picker.backend.fff')
local completion = require('picker.picker.completion')
local M = {}
---@type picker.picker.Snapshot?
local latest

---Files or grep entry point; each invocation owns its source.
---@param options? picker.picker.Options
---@param saved? picker.picker.Snapshot
---@param on_instance? fun(instance: popup.instance)
local function open(options, saved, on_instance)
  if options == nil then
    options = {}
  end

  local origin = vim.api.nvim_get_current_win()
  local session

  local ok, problem = pcall(function()
    if on_instance ~= nil and type(on_instance) ~= 'function' then
      error('on_instance must be a function', 0)
    end
    options = require('picker.picker.options').resolve(options)
    options.on_instance = nil

    local create = options.mode == 'grep' and backend.grep or backend.files
    local source = create(options.cwd or vim.fn.getcwd(), vim.api.nvim_buf_get_name(0))

    session = PickerPanel.new(source, function(_, result)
      completion.execute(result, origin)
    end, options.view, options.keymaps, options.mode == 'grep')
    session:open(on_instance, saved)

    local opened = session
    opened:save_on_close(function()
      latest = require('picker.picker.snapshot').capture(opened, options)
    end)
  end)

  if not ok then
    if session then
      session:close()
    end

    vim.notify('picker: ' .. tostring(problem), vim.log.levels.ERROR)
  end
end

---@param options? picker.picker.Options
function M.open(options)
  local hook
  if type(options) == 'table' then
    hook = options.on_instance
  end
  open(options, nil, hook)
end

---@param options? picker.picker.ResumeOptions
function M.resume(options)
  if not latest then
    vim.notify('picker: no previous session', vim.log.levels.INFO)
    return
  end

  if options ~= nil and type(options) ~= 'table' then
    vim.notify('picker: resume options must be a table', vim.log.levels.ERROR)
    return
  end
  for key in pairs(options or {}) do
    if key ~= 'on_instance' then
      vim.notify('picker: unsupported resume option: ' .. tostring(key), vim.log.levels.ERROR)
      return
    end
  end

  local saved = vim.deepcopy(latest)
  open(saved.options, saved, options and options.on_instance)
end

return M
