local devicons = require('nvim-web-devicons')

local M = {}
local special_labels = {
  fugitive = '[fugitive]',
  oil = '[oil]',
}

function M.buffer_label(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.bo[bufnr].filetype

  local special = special_labels[filetype]
  if special then
    return special, nil, nil
  end

  if name == '' then
    return '[No Name]', nil, nil
  end

  local filename = vim.fn.fnamemodify(name, ':t')
  local icon, color = devicons.get_icon_color(filename, nil, { default = true })
  return filename, icon, color
end

local function normalize(directory)
  local absolute = vim.fn.fnamemodify(directory, ':p'):gsub('/+$', '')
  return absolute ~= '' and absolute or '/'
end

local function directory_context(path)
  local cwd = vim.fn.getcwd()

  local cwd_abs = normalize(cwd)
  local path_abs = normalize(path)
  local home = normalize(vim.fn.expand('~'))
  local cwd_label = cwd_abs == home and '~'
    or cwd_abs == '/' and '/'
    or vim.fn.fnamemodify(cwd_abs, ':t')

  if path_abs == cwd_abs then
    return cwd_label, ''
  end

  local prefix = cwd_abs == '/' and '/' or cwd_abs .. '/'
  if path_abs:sub(1, #prefix) == prefix then
    return cwd_label, path_abs:sub(#prefix + 1), true
  end

  return cwd_label, vim.fn.fnamemodify(path_abs, ':~')
end

function M.workdir(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.bo[bufnr].filetype

  if filetype == 'fugitive' or name == '' then
    return directory_context(vim.fn.getcwd())
  end

  if filetype == 'oil' then
    return directory_context(name:gsub('^oil://', ''))
  end

  if name:match('^%w+://') or vim.bo[bufnr].buftype ~= '' then
    return directory_context(vim.fn.getcwd())
  end

  return directory_context(vim.fn.fnamemodify(name, ':h'))
end

function M.buffer_status(bufnr)
  local filetype = vim.bo[bufnr].filetype
  if filetype == 'fugitive' or filetype == 'oil' then
    return nil
  end

  if vim.bo[bufnr].modified then
    return '[+]'
  end

  if vim.bo[bufnr].readonly or not vim.bo[bufnr].modifiable then
    return '[RO]'
  end

  return nil
end

return M
