---@class OilAdapter.Config
---@field min_pane_size integer
---@field border string
---@field group string
---@field geometry fun(): {width: integer, height: integer, row: integer, col: integer}
---@field oil_title fun(dir: string, cwd: string): table
---@field preview_title fun(): table
---@field keymaps table
---@field oil_win_options table
---@field preview_win_options table

local Panel = require('plugins.explorer.oil.panel')
local api = vim.api
local Adapter = {}
Adapter.__index = Adapter

---@param config OilAdapter.Config
function Adapter.new(config)
  return setmetatable({ config = config }, Adapter)
end

-- Routes actions without reaching into a panel's windows or resource handles.
function Adapter:current_panel()
  local panel = self.active
  if panel and panel:owns_window(api.nvim_get_current_win()) then
    return panel
  end
end

function Adapter:close()
  if vim.bo.filetype == 'oil' and not self:current_panel() then
    return require('oil').close()
  end
  local panel = self.active
  if not panel then
    return
  end
  panel:close()
  panel:restore_origin()
end

function Adapter:select(opts)
  local panel = self:current_panel()
  if panel then
    return panel:select(opts)
  end
  return require('oil').select(opts or {})
end

function Adapter:preview()
  local panel = self:current_panel()
  if panel then
    return panel:toggle_preview()
  end
  return require('oil').open_preview()
end

function Adapter:scroll_preview(direction)
  local panel = self:current_panel()
  if panel then
    panel:scroll_preview(direction)
  end
end

function Adapter:toggle()
  if vim.fn.getcmdwintype() ~= '' then
    vim.notify('Exit the command-line window before opening Oil', vim.log.levels.WARN)
    return
  end
  if self.active then
    return self:close()
  end
  local panel = Panel.new(self.config, function(closed)
    if self.active == closed then
      self.active = nil
    end
  end)
  self.active = panel
  panel:open()
end

return Adapter
