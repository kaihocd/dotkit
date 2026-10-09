---@param p palette.SemanticPalette
---@return palette.HighlightMap
local function semantic(p)
  return {
    ['@lsp.type.decorator'] = { fg = p.blueBright },
    ['@lsp.type.enumMember'] = { fg = p.orange, bold = true },
    ['@lsp.type.keyword'] = { fg = p.purple },
    ['@lsp.type.interface'] = { fg = p.yellow, italic = true },
    ['@lsp.type.namespace'] = { fg = p.yellowBright },
    ['@lsp.type.macro'] = { link = 'Macro' },
    ['@lsp.type.typeParameter'] = { fg = p.yellowBright, italic = true },

    ['@lsp.typemod.function.defaultLibrary'] = { fg = p.blueBright },
    ['@lsp.typemod.variable.defaultLibrary'] = { fg = p.redBright },
    ['@lsp.typemod.variable.readonly'] = { italic = true },
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
---@return palette.HighlightMap
return function(p)
  return vim.tbl_extend('error', semantic(p), diagnostics(p))
end
