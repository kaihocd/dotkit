local colors = require('palette.colors')
local lsp = require('palette.hl-groups.lsp')
local native = require('palette.hl-groups.native')
local plugins = require('palette.hl-groups.plugins')
local syntax = require('palette.hl-groups.syntax')

local M = {}

---@type palette.SemanticPalette?
local current = nil

---Return the last applied palette without exposing its mutable state.
---@return palette.SemanticPalette?
function M.current()
  return current and vim.deepcopy(current) or nil
end

---@param p palette.SemanticPalette
local function apply_terminal_colors(p)
  ---@type palette.HexColor[]
  -- stylua: ignore start
  local terminal_colors = {
    p.bg, p.red, p.green, p.yellow, p.blue,
    p.purple, p.cyan, p.fg, p.fgGhost, p.redBright,
    p.greenBright, p.yellowBright, p.blueBright,
    p.purpleBright, p.cyanBright, p.fgMax,
  }
  -- stylua: ignore end

  for index, color in ipairs(terminal_colors) do
    vim.g['terminal_color_' .. index - 1] = color
  end
end

---@param theme palette.PaletteTheme
---@return palette.SemanticPalette semantic_palette
function M.apply(theme)
  local palette = colors.semantic(theme)
  vim.o.termguicolors = true
  vim.o.background = palette.variant

  for _, definitions in ipairs({
    native(palette),
    syntax(palette),
    lsp(palette),
    plugins(palette),
  }) do
    for group, definition in pairs(definitions) do
      vim.api.nvim_set_hl(0, group, definition)
    end
  end

  apply_terminal_colors(palette)
  -- Publish before notifying consumers; they must not reread the theme file.
  current = palette

  vim.api.nvim_exec_autocmds('ColorScheme', {
    pattern = vim.g.colors_name or 'palette',
    modeline = false,
  })

  return palette
end

return M
