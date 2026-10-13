local colors = require('palette.colors')

---@param p palette.SemanticPalette
---@return palette.HighlightMap
return function(p)
  return {
    -- Terminal selection emphasizes text without painting separate virtual-text blocks.
    TerminalListActive = { fg = p.blue },

    MiniDiffSignAdd = { fg = p.green },
    MiniDiffSignChange = { fg = p.blue },
    MiniDiffSignDelete = { fg = p.red },
    MiniDiffOverAdd = { link = 'DiffAdd' },
    MiniDiffOverDelete = { link = 'DiffDelete' },
    MiniDiffOverChange = { bg = colors.blend(p.red, 0.35, p.bg) },
    MiniDiffOverChangeBuf = { bg = colors.blend(p.green, 0.35, p.bg) },
    MiniDiffOverContext = { link = 'DiffDelete' },
    MiniDiffOverContextBuf = { link = 'DiffAdd' },

    GitGraphHash = { fg = p.blue },
    GitGraphTimestamp = { fg = p.fgDim },
    GitGraphAuthor = { fg = p.fg },
    GitGraphBranchName = { fg = p.green, bold = true },
    GitGraphBranchTag = { fg = p.yellow },
    GitGraphBranchMsg = { fg = p.fg },
    GitGraphBranch1 = { fg = p.blue },
    GitGraphBranch2 = { fg = p.green },
    GitGraphBranch3 = { fg = p.yellow },
    GitGraphBranch4 = { fg = p.red },
    GitGraphBranch5 = { fg = p.purple },

    -- Ibl
    IblIndent = { link = 'WinSeparator' },

    -- Nvim treesitter context
    TreesitterContext = { link = 'Normal' },
    TreesitterContextLineNumber = { link = 'LineNr' },
    TreesitterContextSeparator = { link = 'WinSeparator' },

    -- Blink
    BlinkCmpMenu = { link = 'Pmenu' },
    BlinkCmpMenuBorder = { link = 'PreviewBorder' },
    BlinkCmpMenuSelection = { link = 'Visual' },
    --
    BlinkCmpDoc = { link = 'NormalFloat' },
    BlinkCmpDocBorder = { link = 'FloatBorder' },
    BlinkCmpDocSeparator = { link = 'LineNr' },
    --
    BlinkCmpSignatureHelp = { link = 'NormalFloat' },
    BlinkCmpSignatureHelpBorder = { link = 'FloatBorder' },

    -- Glance
    GlanceListNormal = { link = 'NormalFloat' },
    GlanceListEndOfBuffer = { link = 'FloatBorder' },
    GlanceFoldIcon = { link = 'Comment' },
    --
    GlancePreviewNormal = { link = 'Pmenu' },
    GlancePreviewBorderBottom = { link = 'PreviewBorder' },
    GlancePreviewEndOfBuffer = { link = 'PreviewBorder' },
    GlancePreviewCursorLine = { link = 'PmenuSel' },
    GlancePreviewMatch = { link = 'Search' },
    GlancePreviewSignColumn = { link = 'Pmenu' },
    GlancePreviewFoldColumn = { link = 'Pmenu' },
    --
    GlanceWinBarFilename = { bg = p.bgDeep, fg = p.fgBright, bold = true },
    GlanceWinBarFilepath = { bg = p.bgDeep, fg = p.fgDim },
    GlanceWinBarTitle = { link = 'GlanceWinBarFilename' },
  }
end
