local function escape(text)
  return text:gsub('%%', '%%%%')
end

local mode_names = {
  n = 'NORMAL',
  i = 'INSERT',
  v = 'VISUAL',
  V = 'V-LINE',
  ['\22'] = 'V-BLOCK',
  s = 'SELECT',
  S = 'S-LINE',
  ['\19'] = 'S-BLOCK',
  R = 'REPLACE',
  c = 'COMMAND',
  r = 'PROMPT',
  ['!'] = 'SHELL',
  t = 'TERMINAL',
}

local mode = {
  provider = function()
    local current = vim.api.nvim_get_mode().mode
    local label = current:sub(1, 2) == 'no' and 'OPERATOR'
      or mode_names[current:sub(1, 1)]
      or current
    return ' ' .. escape(label) .. ' '
  end,
  hl = { fg = 'fg', bold = true },
}

local branch = {
  provider = function()
    if vim.fn.exists('*FugitiveHead') == 0 then
      return ''
    end
    local head = vim.fn.FugitiveHead()
    return head ~= '' and ' ' .. escape(head) .. ' ' or ''
  end,
  hl = { fg = 'fgDim' },
}

local diagnostics = {
  init = function(self)
    local counts = vim.diagnostic.count(0)
    self.errors = counts[vim.diagnostic.severity.ERROR] or 0
    self.warnings = counts[vim.diagnostic.severity.WARN] or 0
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
    return #names > 0 and ' [' .. escape(table.concat(names, ' ')) .. '] ' or ''
  end,
  hl = { fg = 'fgDim' },
}

return {
  hl = { fg = 'fg', bg = 'bgHigher' },
  mode,
  branch,
  diagnostics,
  recording,
  { provider = '%=' },
  lsp,
  { provider = ' %l:%v  %p%% ', hl = { fg = 'fgDim' } },
}
