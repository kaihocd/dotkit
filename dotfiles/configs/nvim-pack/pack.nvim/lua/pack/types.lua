---@meta

---@class pack.UserSpec
---@field src? string
---@field path? string
---@field name? string
---@field version? string
---@field event? string|string[]
---@field ft? string|string[]
---@field main? string Lua module used for automatic setup; inferred from plugin name when omitted.
---@field opts? table Options passed to automatic setup or custom config.
---@field config? false|fun(opts: table) Set false to disable automatic setup.
---@field build? fun(context: pack.BuildContext)
---@field deps? pack.UserSpec[]

---@class pack.BuildContext
---@field name string
---@field path string
---@field source string

---@class pack.Status
---@field loaded string[]
---@field waiting string[]
---@field missing string[]
---@field stale string[]
---@field conflict string[]
