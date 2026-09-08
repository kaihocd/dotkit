local Instance = require('popup.instance')
local External = require('popup.instance.external')
local spec = require('popup.spec')

local M = {}

---@param config? popup.spec.pane
---@return popup.node.pane
function M.pane(config)
  return spec.pane(config)
end

---@param config popup.spec.flex
---@return popup.node.row
function M.row(config)
  return spec.row(config)
end

---@param config popup.spec.flex
---@return popup.node.col
function M.col(config)
  return spec.col(config)
end

M.group = require('popup.group').create

---@param config popup.spec.root
---@return popup.instance
function M.root(config)
  return Instance.new(spec.root(config))
end

---@param opts table
---@return popup.external
function M.external(opts)
  return External.new(opts)
end

return M
