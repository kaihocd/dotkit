local colors = require('palette.colors')

---@param p palette.SemanticPalette
---@return palette.HighlightMap
return function(p)
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
    Folded = { bg = p.bgHighest },

    WinSeparator = { fg = p.fgGhost },
    StatusLine = { bg = p.bgHigher, fg = p.fg },
    StatusLineNC = { bg = p.bgHigher, fg = p.fgDim },
    WinBar = { link = 'StatusLine' },
    WinBarNC = { link = 'StatusLineNC' },
    TabLine = { link = 'StatusLineNC' },
    TabLineFill = { bg = p.bgHigher },
    TabLineSel = { link = 'StatusLine' },

    Visual = { bg = p.bgHighest },
    VisualNOS = { link = 'Visual' },
    Search = { bg = colors.blend(p.orange, 0.2, p.bg) },
    IncSearch = { bg = p.orange, fg = colors.most_contrasting(p.orange, p.bgDeep, p.fgMax) },
    CurSearch = { link = 'IncSearch' },
    Substitute = { link = 'IncSearch' },
    MatchParen = { bg = p.bgHighest, fg = p.blue, bold = true },

    NormalFloat = { bg = p.bgDeep, fg = p.fg },
    FloatBorder = { bg = p.bgDeep, fg = p.bgDeep },
    FloatTitle = { bg = p.blue, fg = p.bgDeep, bold = true },
    PreviewBorder = { bg = p.bgHigher, fg = p.bgHigher },
    PreviewTitle = { bg = p.blue, fg = p.bgHigher, bold = true },
    Pmenu = { bg = p.bgHigher, fg = p.fg },
    PmenuSel = { bg = colors.blend(p.blue, 0.25, p.bgHigher), fg = p.fgMax, bold = true },
    PmenuSbar = { bg = p.bgHigher },
    PmenuThumb = { bg = p.fgGhost },
    WildMenu = { link = 'PmenuSel' },

    DiffAdd = { bg = colors.blend(p.green, 0.2, p.bg) },
    DiffChange = { bg = colors.blend(p.yellow, 0.2, p.bg) },
    DiffDelete = { bg = colors.blend(p.red, 0.2, p.bg) },
    DiffText = { bg = colors.blend(p.yellow, 0.35, p.bg) },
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
