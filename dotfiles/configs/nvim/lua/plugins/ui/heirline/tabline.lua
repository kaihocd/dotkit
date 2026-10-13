local colors = require('palette.colors')
local context = require('plugins.ui.heirline.context')
local heirline = require('heirline.utils')
local heirline_highlights = require('heirline.highlights')

local function escape(text)
  return text:gsub('%%', '%%%%')
end

local function faded_icon_color(icon_color)
  if not icon_color then
    return nil
  end
  return colors.blend(icon_color, 0.5, heirline_highlights.get_loaded_colors().bg)
end

-- Keep complete directory names; initials lose the useful location context.
local function directory_tail(directory, count)
  local parts = vim.split(directory, '/', { trimempty = true })
  if #parts <= count then
    return directory
  end
  local shortened = '…/' .. table.concat(parts, '/', #parts - count + 1)
  return vim.fn.strdisplaywidth(shortened) < vim.fn.strdisplaywidth(directory) and shortened
    or directory
end

local function directory_provider(count)
  return function(self)
    local directory = count and directory_tail(self.directory, count) or self.directory
    if directory == '' then
      return ''
    end
    local separator = self.within_cwd and (self.cwd_name == '/' and '' or '/') or '  '
    return separator .. escape(directory)
  end
end

local workdir = {
  init = function(self)
    self.cwd_name, self.directory, self.within_cwd = context.workdir(0)
  end,
  {
    provider = function(self)
      return escape(self.cwd_name)
    end,
    hl = { fg = 'fg', bg = 'bgHigher' },
  },
  {
    -- Higher priority: preserve directory context until the tabs have contracted.
    flexible = 20,
    hl = { fg = 'fgDim', bg = 'bgHigher' },
    { provider = directory_provider() },
    { provider = directory_provider(2) },
    { provider = directory_provider(1) },
    { provider = '' },
  },
}

local tab = {
  init = function(self)
    local bufnr = vim.api.nvim_win_get_buf(vim.api.nvim_tabpage_get_win(self.tabpage))
    self.label, self.icon, self.icon_color = context.buffer_label(bufnr)
    self.status = context.buffer_status(bufnr)
  end,
  hl = function(self)
    return {
      fg = self.is_active and 'fg' or 'fgDim',
      bg = self.is_active and 'bg' or 'bgHigher',
    }
  end,
  {
    provider = function(self)
      return ('%%%dT'):format(vim.api.nvim_tabpage_get_number(self.tabpage))
    end,
  },
  {
    provider = '▏',
    hl = function(self)
      return { fg = self.is_active and 'blue' or 'fgGhost' }
    end,
  },
  {
    provider = function(self)
      return self.icon and self.icon .. ' ' or ''
    end,
    hl = function(self)
      return { fg = self.is_active and self.icon_color or faded_icon_color(self.icon_color) }
    end,
  },
  {
    provider = function(self)
      return escape(self.label)
    end,
    hl = function(self)
      return { bold = self.is_active }
    end,
  },
  {
    provider = function(self)
      return self.status and ' ' .. escape(self.status) or ''
    end,
  },
  { provider = ' ' },
  { provider = '%T' },
}

local position = {
  {
    provider = '▏',
    hl = function()
      return { fg = 'fgGhost', bg = 'bgHigher' }
    end,
  },
  {
    provider = function()
      return ('%d/%d '):format(vim.api.nvim_tabpage_get_number(0), #vim.api.nvim_list_tabpages())
    end,
    hl = { fg = 'fgDim' },
  },
}

local tablist = {
  flexible = 10,
  heirline.make_tablist(tab),
  { static = { compact = true }, heirline.make_tablist(tab) },
  {
    init = function(self)
      self.tabpage = vim.api.nvim_get_current_tabpage()
      self.is_active = true
    end,
    static = { compact = true },
    tab,
    position,
  },
  -- Very narrow windows: retain the active tab number without a filename.
  position,
}

return {
  {
    { provider = ' ' },
    workdir,
    { provider = ' ' },
    { provider = '%=' },
    { provider = ' ' },
    tablist,
    { provider = ' ' },
    hl = { bg = 'bgHigher' },
  },
}
