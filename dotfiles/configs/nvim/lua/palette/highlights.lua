local colors = require('palette.colors')

local M = {}

---@param p palette.SemanticPalette
---@return palette.HighlightMap
local function native(p)
  return {
    Normal = { bg = p.bg, fg = p.fg },
    NormalNC = { link = 'Normal' },
    EndOfBuffer = { fg = p.bg },
    NonText = { fg = p.fgGhost },
    Whitespace = { link = 'NonText' },
    SpecialKey = { link = 'NonText' },
    Directory = { fg = p.blue },

    LineNr = { fg = p.fgGhost },
    LineNrAbove = { link = 'LineNr' },
    LineNrBelow = { link = 'LineNr' },
    CursorLine = { bg = p.bgHigher },
    CursorColumn = { link = 'CursorLine' },
    CursorLineNr = { fg = p.fgMax, bold = true },
    ColorColumn = { bg = p.bgHigher },
    SignColumn = { fg = p.fgDim },
    FoldColumn = { fg = p.blue },
    Folded = { bg = p.bgHigher, fg = p.blue },

    WinSeparator = { fg = p.bgHighest },
    StatusLine = { bg = p.bgHigher, fg = p.fg },
    StatusLineNC = { bg = p.bgHigher, fg = p.fgDim },
    WinBar = { link = 'StatusLine' },
    WinBarNC = { link = 'StatusLineNC' },
    TabLine = { link = 'StatusLineNC' },
    TabLineFill = { bg = p.bgHigher },
    TabLineSel = { link = 'StatusLine' },

    Visual = { bg = p.bgHighest },
    VisualNOS = { link = 'Visual' },
    Search = { bg = colors.blend(p.orange, 0.25, p.bg) },
    IncSearch = { bg = p.orange, fg = colors.most_contrasting(p.orange, p.bgDeep, p.fgMax) },
    CurSearch = { link = 'IncSearch' },
    Substitute = { link = 'IncSearch' },
    MatchParen = { bg = colors.blend(p.blue, 0.25, p.bg), bold = true },

    NormalFloat = { bg = p.bgDeep, fg = p.fg },
    FloatBorder = { bg = p.bgDeep, fg = p.fgGhost },
    FloatTitle = { bg = p.bgDeep, fg = p.blue, bold = true },
    Pmenu = { bg = p.bgHigher, fg = p.fg },
    PmenuSel = { bg = colors.blend(p.blue, 0.25, p.bgHigher), fg = p.fgMax, bold = true },
    PmenuSbar = { bg = p.bgHigher },
    PmenuThumb = { bg = p.fgGhost },
    WildMenu = { link = 'PmenuSel' },

    DiffAdd = { bg = colors.blend(p.green, 0.2, p.bg) },
    DiffChange = { bg = colors.blend(p.yellow, 0.2, p.bg) },
    DiffDelete = { bg = colors.blend(p.red, 0.2, p.bg) },
    DiffText = { bg = colors.blend(p.yellow, 0.35, p.bg), underline = true },
    Added = { fg = p.green },
    Changed = { fg = p.yellow },
    Removed = { fg = p.red },

    SpellBad = { undercurl = true, sp = p.red },
    SpellCap = { undercurl = true, sp = p.yellow },
    SpellLocal = { undercurl = true, sp = p.cyan },
    SpellRare = { undercurl = true, sp = p.purple },

    MsgSeparator = { link = 'WinSeparator' },
    ModeMsg = { fg = p.fgBright, bold = true },
    MsgArea = { fg = p.fg },
    MoreMsg = { fg = p.green },
    WarningMsg = { fg = p.yellow },
    ErrorMsg = { fg = p.red, bold = true },
    Question = { fg = p.cyan },
    Title = { fg = p.blue, bold = true },
    QuickFixLine = { link = 'CursorLine' },
    Conceal = { fg = p.fgDim },
  }
end

---@param p palette.SemanticPalette
---@return palette.HighlightMap
local function syntax(p)
  return {
    Comment = { fg = p.fgDim, italic = true },
    Constant = { fg = p.orange },
    String = { fg = p.green },
    Character = { link = 'String' },
    Number = { link = 'Constant' },
    Boolean = { link = 'Constant' },
    Float = { link = 'Constant' },
    Identifier = { fg = p.fg },
    Function = { fg = p.blue },
    Statement = { fg = p.red },
    Conditional = { link = 'Statement' },
    Repeat = { link = 'Statement' },
    Label = { link = 'Statement' },
    Operator = { fg = p.cyanBright },
    Keyword = { link = 'Statement' },
    Exception = { fg = p.redBright, bold = true },
    PreProc = { fg = p.yellowBright },
    Include = { link = 'PreProc' },
    Define = { link = 'PreProc' },
    Macro = { link = 'PreProc' },
    PreCondit = { link = 'PreProc' },
    Type = { fg = p.yellow },
    StorageClass = { fg = p.red },
    Structure = { link = 'Type' },
    Typedef = { link = 'Type' },
    Special = { fg = p.cyan },
    SpecialChar = { fg = p.cyanBright },
    Tag = { fg = p.redBright },
    Delimiter = { fg = p.fgGhost },
    SpecialComment = { fg = p.fgBright, bold = true },
    Debug = { fg = p.redBright },
    Underlined = { underline = true },
    Ignore = { fg = p.bg },
    Error = { fg = p.redBright, underline = true },
    Todo = { fg = p.cyanBright, bold = true },
  }
end

---@param p palette.SemanticPalette
---@return palette.HighlightMap
local function diagnostics(p)
  ---@type palette.HighlightMap
  local groups = {}
  local levels = {
    Error = p.red,
    Warn = p.yellow,
    Info = p.blue,
    Hint = p.cyan,
    Ok = p.green,
  }

  for level, color in pairs(levels) do
    groups['Diagnostic' .. level] = { fg = color }
    groups['DiagnosticVirtualText' .. level] = { fg = color }
    groups['DiagnosticUnderline' .. level] = { undercurl = true, sp = color }
    groups['DiagnosticFloating' .. level] = { link = 'Diagnostic' .. level }
    groups['DiagnosticSign' .. level] = { link = 'Diagnostic' .. level }
  end

  groups.DiagnosticDeprecated = { fg = p.fgDim, strikethrough = true }
  groups.DiagnosticUnnecessary = { fg = p.fgDim, italic = true }
  return groups
end

---@param p palette.SemanticPalette
local function apply_terminal_colors(p)
  ---@type palette.HexColor[]
  local terminal_colors = {
    p.bg,
    p.red,
    p.green,
    p.yellow,
    p.blue,
    p.purple,
    p.cyan,
    p.fg,
    p.fgGhost,
    p.redBright,
    p.greenBright,
    p.yellowBright,
    p.blueBright,
    p.purpleBright,
    p.cyanBright,
    p.fgMax,
  }

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

  for _, definitions in ipairs({ native(palette), syntax(palette), diagnostics(palette) }) do
    for group, definition in pairs(definitions) do
      vim.api.nvim_set_hl(0, group, definition)
    end
  end

  apply_terminal_colors(palette)
  return palette
end

return M
