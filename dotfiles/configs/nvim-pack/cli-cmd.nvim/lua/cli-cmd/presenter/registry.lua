---Named presenters: configured once in `setup`, chosen by name per tool.
---
---Configuring a sink and choosing one are separate decisions, so they live in
---separate places:
---
---```lua
---require('cli-cmd').setup({ presenters = { split = { min_height = 3 } } })
---require('cli-cmd').install('git', { presenter = 'split' })
---```
---
---A name that is not built in must name its kind or be a function, so `log` can
---be a `split` with its own height without inventing a fourth kind.
local Output = require('cli-cmd.presenter.output')
local check = require('cli-cmd.guard')('cli-cmd.presenter.registry')

local M = {}

---The kinds the presenter knows how to render, usable without setup. Read from
---the presenter's own declaration so the list cannot drift from what it supports.
local builtin = {}
for name in pairs(Output.defaults.kinds) do
  builtin[name] = true
end

---Presenters by name. This is configuration, not installation state: `setup`
---writes it once and `install` only reads it.
---@type table<string, cli-cmd.OutputPresenter>
local presenters = {}

---@type boolean
local configured = false

---Turn one `setup` entry into a presenter. A built-in name is its own kind, so
---`split = { min_height = 3 }` reads as "configure the split". Any other name
---has to say which kind it is, unless the entry is a function.
---@param name string
---@param spec cli-cmd.ReportConfig|fun(message: string, level: integer)
---@return cli-cmd.OutputPresenter
local function build(name, spec)
  if type(spec) == 'function' then
    return Output.new({ kind = spec })
  end
  check(type(spec) == 'table', "presenter '" .. name .. "' must be a config table or a function")
  local config = vim.deepcopy(spec)
  check(
    config.kind ~= nil or builtin[name] == true,
    "presenter '" .. name .. "' must set kind, or be named after a built-in kind"
  )
  config.kind = config.kind or name
  return Output.new(config)
end

---Replace the whole set of named presenters. Built-in names always exist, so a
---config that only tunes `split` still leaves `tab` and `notify` usable.
---@param config? { presenters?: table<string, cli-cmd.ReportConfig|fun(message: string, level: integer)> }
function M.setup(config)
  local specs = config and config.presenters or {}
  check(type(specs) == 'table', 'presenters must be a table')
  local built = {}
  for name in pairs(builtin) do
    built[name] = Output.new({ kind = name })
  end
  for name, spec in pairs(specs) do
    built[name] = build(name, spec)
  end
  presenters = built
  configured = true
end

---The presenter a tool asks for by name; `nil` means the default kind.
---@param name? string
---@return cli-cmd.OutputPresenter
function M.get(name)
  name = name or Output.defaults.kind
  if not configured then
    M.setup()
  end
  local presenter = presenters[name]
  check(
    presenter ~= nil,
    "no presenter named '"
      .. name
      .. "'; define it in setup({ presenters = { "
      .. name
      .. ' = ... } })'
  )
  return presenter
end

return M
