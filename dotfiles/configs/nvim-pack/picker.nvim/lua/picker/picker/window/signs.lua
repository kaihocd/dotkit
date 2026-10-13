local M = {}

---@param foreground integer
---@param background integer
---@param ratio number
---@return integer
local function blend(foreground, background, ratio)
  local color = 0
  for _, place in ipairs({ 65536, 256, 1 }) do
    local fg = math.floor(foreground / place) % 256
    local bg = math.floor(background / place) % 256
    color = color + math.floor(fg * ratio + bg * (1 - ratio) + 0.5) * place
  end
  return color
end

---Resolve per paint so a new colorscheme never reuses cached RGB values.
---@param status? string
---@param marked boolean
---@param mark_style picker.picker.TextStyle
---@param settings picker.SignConfig
---@return string[]?
function M.marker(status, marked, mark_style, settings)
  if marked then
    return { mark_style.text, mark_style.highlight }
  end
  local marker = status and settings.git[status]
  if not marker or not status or not status:match('^staged_') then
    return marker
  end
  local base = vim.api.nvim_get_hl(0, { name = marker[2], link = false })
  local background = vim.api.nvim_get_hl(0, { name = 'NormalFloat', link = false })
  if not base.fg or not background.bg then
    return marker
  end
  -- The ratio is session configuration; include it in the group identity so
  -- painting one session cannot overwrite another session's staged color.
  local name = string.format(
    'PickerSignStaged_%s_%03d',
    marker[2],
    math.floor(settings.staged_foreground_ratio * 1000 + 0.5)
  )
  vim.api.nvim_set_hl(
    0,
    name,
    { fg = blend(base.fg, background.bg, settings.staged_foreground_ratio), ctermfg = base.ctermfg }
  )
  return { marker[1], name }
end

return M
