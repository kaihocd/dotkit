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

-- The branch comes from HEAD itself, so the statusline needs no Git process and
-- no plugin: one small file per directory, cached until something can move HEAD.
local heads = {}

-- `.git` is a directory in a normal clone and a `gitdir:` file in a worktree, so
-- walk up by hand instead of trusting a single file type.
local function git_entry(directory)
  local current = directory
  while current do
    local entry = vim.fs.joinpath(current, '.git')
    if vim.uv.fs_stat(entry) then
      return entry
    end
    local parent = vim.fs.dirname(current)
    current = parent ~= current and parent or nil
  end
  return nil
end

local function read_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and lines or nil
end

local function git_directory(directory)
  local entry = git_entry(directory)
  if not entry then
    return nil
  end
  if vim.fn.isdirectory(entry) == 1 then
    return entry
  end
  local linked = ((read_lines(entry) or {})[1] or ''):match('^gitdir:%s*(.+)$')
  if not linked then
    return nil
  end
  if linked:sub(1, 1) ~= '/' then
    linked = vim.fs.joinpath(vim.fs.dirname(entry), linked)
  end
  return vim.fs.normalize(linked)
end

local function read_head(directory)
  local git_dir = git_directory(directory)
  local lines = git_dir and read_lines(vim.fs.joinpath(git_dir, 'HEAD'))
  if not lines then
    return ''
  end
  local head = lines[1] or ''
  return head:match('^ref:%s*refs/heads/(.+)$') or head:match('^(%x%x%x%x%x%x%x)') or ''
end

local function head_name(directory)
  if heads[directory] == nil then
    heads[directory] = read_head(directory)
  end
  return heads[directory]
end

vim.api.nvim_create_autocmd({ 'BufEnter', 'DirChanged', 'FocusGained' }, {
  group = vim.api.nvim_create_augroup('StatuslineHead', { clear = true }),
  callback = function()
    heads = {}
  end,
})

local branch = {
  provider = function()
    local head = head_name(vim.fn.getcwd())
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
