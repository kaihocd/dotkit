local devicons = require('nvim-web-devicons')

local M = {}

local function uri_label(name)
  local scheme = name:match('^([%w][%w+.-]*)://')
  return scheme and '[' .. scheme .. ']' or nil
end

function M.buffer_label(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local uri = uri_label(name)
  if uri then
    return uri, nil, nil
  end

  if name == '' then
    return '[No Name]', nil, nil
  end

  local filename = vim.fn.fnamemodify(name, ':t')
  local icon, color = devicons.get_icon_color(filename, nil, { default = false })
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
  if name == '' then
    return directory_context(vim.fn.getcwd())
  end

  local uri_path = name:match('^[%w][%w+.-]*://(.+)$')
  if uri_path and uri_path:sub(1, 1) == '/' and vim.fn.isdirectory(uri_path) == 1 then
    return directory_context(uri_path)
  end

  if uri_label(name) or vim.bo[bufnr].buftype ~= '' then
    return directory_context(vim.fn.getcwd())
  end

  return directory_context(vim.fn.fnamemodify(name, ':h'))
end

function M.buffer_status(bufnr)
  -- URI buffers represent plugin views; transient write options are not file status.
  if uri_label(vim.api.nvim_buf_get_name(bufnr)) then
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
