---LSP config factory
---@alias devtool.server_config_factory fun(): table<string, unknown>

---@class devtool.config
---@field ensure_installed string[] LSP servers to install.
---@field configs table<string, devtool.server_config_factory> Per-server lazy configurations.

---@type devtool.config
return {
  ensure_installed = {
    'html',
    'cssls',
    'eslint',
    'oxlint',
    'tsc',
    'lua_ls',
    'jsonls',
  },
  configs = {
    lua_ls = function()
      return {
        settings = {
          Lua = {
            diagnostics = {
              workspaceEvent = 'OnChange',
              workspaceDelay = 500,
            },
          },
        },
      }
    end,
    jsonls = function()
      return {
        settings = {
          json = {
            schemas = require('schemastore').json.schemas(),
            validate = { enable = true },
          },
        },
      }
    end,
  },
}
