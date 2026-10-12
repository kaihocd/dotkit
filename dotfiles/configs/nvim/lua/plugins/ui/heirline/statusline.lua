local mode_names = {
  n = 'N',
  i = 'I',
  v = 'V',
  V = 'V',
  ['\22'] = 'V',
  s = 'S',
  S = 'S',
  ['\19'] = 'S',
  R = 'R',
  c = 'C',
  r = 'P',
  ['!'] = '!',
  t = 'T',
}

local function escape(text)
  return text:gsub('%%', '%%%%')
end

local mode = {
  init = function(self)
    self.mode_label = mode_names[vim.api.nvim_get_mode().mode:sub(1, 1)] or '?'
  end,
  provider = function(self)
    return ' ' .. self.mode_label .. ' '
  end,
  hl = { fg = 'fg', bold = true },
}

local branch = {
  provider = function()
    local summary = vim.b.minigit_summary
    local head = type(summary) == 'table' and summary.head_name or ''
    head = head or ''
    return head ~= '' and ' ' .. escape(head) .. ' ' or ''
  end,
  hl = { fg = 'fgDim' },
}

local diagnostics = {
  init = function(self)
    local counts = vim.diagnostic.count(0)
    self.errors = counts[vim.diagnostic.severity.ERROR] or 0
    self.warnings = counts[vim.diagnostic.severity.WARN] or 0
    self.infos = counts[vim.diagnostic.severity.INFO] or 0
    self.hints = counts[vim.diagnostic.severity.HINT] or 0
  end,
  {
    provider = function(self)
      return self.errors > 0 and (' E%d'):format(self.errors) or ''
    end,
    hl = { fg = 'red' },
  },
  {
    provider = function(self)
      return self.warnings > 0 and (' W%d'):format(self.warnings) or ''
    end,
    hl = { fg = 'yellow' },
  },
  {
    provider = function(self)
      return self.infos > 0 and (' I%d'):format(self.infos) or ''
    end,
    hl = { fg = 'blue' },
  },
  {
    provider = function(self)
      return self.hints > 0 and (' H%d'):format(self.hints) or ''
    end,
    hl = { fg = 'cyan' },
  },
}

local recording = {
  provider = function()
    local register = vim.fn.reg_recording()
    return register ~= '' and ' REC @' .. escape(register) .. ' ' or ''
  end,
  hl = { fg = 'red' },
}

local lsp = {
  provider = function()
    local names, seen = {}, {}
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
      if client.initialized and not client:is_stopped() and not seen[client.name] then
        names[#names + 1] = client.name
        seen[client.name] = true
      end
    end
    table.sort(names)
    return #names > 0 and ' ' .. escape(table.concat(names, ',')) .. ' ' or ''
  end,
  hl = { fg = 'fgDim' },
}

return {
  hl = { fg = 'fg', bg = 'bgHigher' },
  mode,
  branch,
  diagnostics,
  { provider = '%=' },
  recording,
  lsp,
  -- Reserve numeric columns so cursor movement does not shift the LSP region.
  { provider = ' %4l:%-3v %3p%% ', hl = { fg = 'fgDim' } },
}
