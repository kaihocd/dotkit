---The Git tool: `require('cli.git').setup()` registers `:Git`.
---
---What makes Git different from another tool lives here and nowhere else: the
---default route preset, the editor bridge that hands commit messages back to
---this Neovim, and the completion provider that asks Git itself.
local Commands = require('cli.commands')
local Git = require('cli.adapter.git')
local check = require('cli.guard')('cli.git')

local M = {}

---The Git tool's defaults; `setup` accepts anything `cli.ToolOptions` describes.
---@type cli.ToolOptions
local defaults = {
  executable = 'git',
  command = 'Git',
  editor = true,
}

---`false` disables completion; a table is passed to the provider; a function is
---used as the per-directory provider factory as-is.
---@param option false|table|function|nil
---@return fun(cwd: string): fun(query: table): string[]?
local function completion_of(option)
  if type(option) == 'function' then
    return option
  end
  check(option == nil or type(option) == 'table', 'completion must be a table, false, or nil')
  local options = vim.deepcopy(option or {})
  return function(cwd)
    return require('cli.completion.git').new(vim.tbl_extend('force', options, { cwd = cwd }))
  end
end

---@param spec cli.ToolSpec
---@param parts cli.ToolParts
---@return table command
local function build(spec, parts)
  return Git.new({
    cwd = parts.cwd,
    executable = spec.executable,
    routes = spec.routes,
    replace_routes = spec.replace_routes,
    fallback = spec.fallback,
    backends = spec.backends,
    env = spec.env,
    editor = parts.editor,
    presenter = parts.presenter,
    terminal_capability = spec.terminal_capability,
    terminal_layout = spec.terminal_layout,
  })
end

---Install Git as a Neovim command.
---
---With no options this installs `:Git`: it runs Git in the current directory,
---edits commit messages in this Neovim, and completes from Git's own output.
---@param opts? cli.ToolOptions
---@return cli.Tool
function M.setup(opts)
  check(opts == nil or type(opts) == 'table', 'options must be a table')
  local spec = vim.tbl_extend('force', defaults, opts or {})
  spec.name = 'git'
  spec.build = build
  spec.route_key = Git.route_key
  if spec.completion == false then
    spec.completion = nil
  else
    spec.completion = completion_of(spec.completion)
  end
  check(
    spec.routes == nil or type(spec.routes) == 'table',
    'routes must be a table; use replace_routes to drop the preset'
  )
  return Commands.install(spec)
end

return M
