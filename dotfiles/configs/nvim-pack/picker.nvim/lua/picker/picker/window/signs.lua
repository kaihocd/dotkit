local config = require('picker.picker.config')
local M = {}

---@param foreground integer
---@param background integer
---@return integer
local function blend(foreground, background)
  local color = 0
  for _, place in ipairs({ 65536, 256, 1 }) do
    local fg = math.floor(foreground / place) % 256
    local bg = math.floor(background / place) % 256
    color = color
      + math.floor(
          fg * config.staged_foreground_ratio + bg * (1 - config.staged_foreground_ratio) + 0.5
        )
        * place
  end
  return color
end

---Resolve per paint so a new colorscheme never reuses cached RGB values.
---@param status? string
---@param marked boolean
---@param mark_style? picker.picker.TextStyle
---@return string[]?
function M.marker(status, marked, mark_style)
  if marked then
    local style = mark_style or { text = '▊', highlight = 'Title' }
    return { style.text, style.highlight }
  end
  local marker = status and config.git[status]
  if not marker or not status or not status:match('^staged_') then
    return marker
  end
  local base = vim.api.nvim_get_hl(0, { name = marker[2], link = false })
  local background = vim.api.nvim_get_hl(0, { name = 'NormalFloat', link = false })
  if not base.fg or not background.bg then
    return marker
  end
  local name = 'PickerSignStaged_' .. marker[2]
  vim.api.nvim_set_hl(0, name, { fg = blend(base.fg, background.bg), ctermfg = base.ctermfg })
  return { marker[1], name }
end

return M
