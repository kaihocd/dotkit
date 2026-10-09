local colors = require('palette.colors')
local context = require('plugins.ui.heirline.context')
local heirline = require('heirline.utils')
local heirline_highlights = require('heirline.highlights')

local function current_buffer(tabpage)
  local win = vim.api.nvim_tabpage_get_win(tabpage)
  return vim.api.nvim_win_get_buf(win)
end

local function escape(text)
  return text:gsub('%%', '%%%%')
end

local function faded_icon_color(icon_color)
  if not icon_color then
    return nil
  end

  local palette = heirline_highlights.get_loaded_colors()
  return colors.blend(icon_color, 0.5, palette.bg)
end

local workdir = {
  init = function(self)
    self.cwd_name, self.directory = context.workdir(0)
  end,
  {
    provider = function(self)
      return escape(self.cwd_name)
    end,
    hl = { fg = 'fg', bg = 'bgHigher', bold = true },
  },
  {
    provider = function(self)
      return self.directory ~= '' and '  ' .. escape(self.directory) or ''
    end,
    hl = { fg = 'fgDim', bg = 'bgHigher' },
  },
}

local tabs = heirline.make_tablist({
  init = function(self)
    local bufnr = current_buffer(self.tabpage)
    local label, icon, icon_color = context.buffer_label(bufnr)
    local status = context.buffer_status(bufnr)
    self.label = label
    self.icon = icon
    self.icon_color = icon_color
    self.status = status
  end,
  hl = function(self)
    return {
      fg = self.is_active and 'fg' or 'fgDim',
      bg = self.is_active and 'bg' or 'bgHigher',
    }
  end,
  -- Resolve the number at render time: tab handles survive :tabmove, numbers do not.
  {
    provider = function(self)
      return ('%%%dT'):format(vim.api.nvim_tabpage_get_number(self.tabpage))
    end,
  },
  {
    provider = function(self)
      return self.is_active and '▎' or '▏'
    end,
    hl = function(self)
      return {
        fg = self.is_active and 'blue' or 'fgDim',
      }
    end,
  },
  {
    provider = function(self)
      return self.icon and self.icon .. ' ' or ''
    end,
    hl = function(self)
      return {
        fg = self.is_active and self.icon_color or faded_icon_color(self.icon_color),
      }
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
})

return {
  {
    { provider = ' ' },
    workdir,
    { provider = '%=' },
    tabs,
    { provider = ' ' },
    hl = { bg = 'bgHigher' },
  },
}
