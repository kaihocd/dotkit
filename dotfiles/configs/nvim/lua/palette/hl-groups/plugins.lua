---@param p palette.SemanticPalette
---@return palette.HighlightMap
return function(p)
  return {
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
