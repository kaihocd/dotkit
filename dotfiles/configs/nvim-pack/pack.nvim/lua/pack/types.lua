---@meta

---@class pack.UserSpec
---@field src? string
---@field path? string
---@field name? string
---@field version? string
---@field event? string|string[]
---@field ft? string|string[]
---@field opts? table
---@field config? fun(opts: table)
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
