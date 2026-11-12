-- Configuration boundary. Runtime consumers receive resolved snapshots, never
-- this module's defaults or configured state.
---@class picker.SearchConfig
---@field debounce_ms integer
---@field scan_poll_ms integer
---@field grep_page_size integer
---@field resume_grep_pages integer

---@class picker.PreviewConfig
---@field max_files integer
---@field max_bytes integer
---@field radius integer
---@field max_prefetch integer

---@class picker.SignOptions
---@field staged_foreground_ratio? number
---@field git? table<string, string[]>
---@class picker.SignConfig: picker.SignOptions
---@field staged_foreground_ratio number
---@field git table<string, string[]>
---@class picker.SearchOptions
---@field debounce_ms? integer
---@field scan_poll_ms? integer
---@field grep_page_size? integer
---@field resume_grep_pages? integer
---@class picker.PreviewOptions
---@field max_files? integer
---@field max_bytes? integer
---@field radius? integer
---@field max_prefetch? integer
---@class picker.SetupOptions
---@field picker? {view?: picker.picker.ViewOptions, keymaps?: picker.picker.Keymaps, search?: picker.SearchOptions, preview?: picker.PreviewOptions}
---@field select? {view?: picker.select.ViewOptions, keymaps?: table}

---@class picker.PickerConfig
---@field view picker.picker.ResolvedView
---@field keymaps picker.picker.Keymaps
---@field search picker.SearchConfig
---@field preview picker.PreviewConfig

---@class picker.SelectConfig
---@field view picker.select.ResolvedView
---@field keymaps table<string, table<string, string|false|function>>

local schema = require('picker.config.schema')
local rules = require('picker.config.rules')
local checks = require('picker.config.checks')
local invocation = require('picker.config.invocation')

local kinds = { picker = true, select = true }
local defaults = {
  picker = require('picker.config.defaults.picker'),
  select = require('picker.config.defaults.select'),
}

local M = {}

local configured

---@param kind 'picker'|'select'
---@param resolved table
local function check(kind, resolved)
  local problem
  if kind == 'picker' then
    problem = checks.picker(resolved)
  else
    problem = checks.select(resolved.view)
  end
  if problem then
    error('picker: ' .. problem, 0)
  end
end

---@param options? picker.SetupOptions
function M.setup(options)
  options = options or {}
  schema.validate_record(options, defaults, 'setup', rules)

  local normalized = vim.deepcopy(options)
  if normalized.picker then
    normalized.picker = invocation.normalize(normalized.picker)
  end

  local next_config = schema.merge(defaults, normalized)
  check('picker', next_config.picker)
  check('select', next_config.select)
  configured = next_config
end

function M.assert_setup()
  if not configured then
    error('picker: setup() must be called before using the API', 0)
  end
end

---@overload fun(kind: 'picker', overrides?: picker.picker.Options): picker.PickerConfig
---@overload fun(kind: 'select', overrides?: picker.select.Options): picker.SelectConfig
---@param kind 'picker'|'select'
---@param overrides? table
---@return picker.PickerConfig|picker.SelectConfig
function M.resolve(kind, overrides)
  M.assert_setup()
  if not kinds[kind] then
    error('picker: unknown configuration kind: ' .. tostring(kind), 0)
  end
  overrides = overrides or {}

  schema.validate_record(overrides, configured[kind], kind, rules)
  local normalized = kind == 'picker' and invocation.normalize(overrides) or overrides
  local resolved = schema.merge(configured[kind], normalized)
  check(kind, resolved)
  return resolved
end

return M
