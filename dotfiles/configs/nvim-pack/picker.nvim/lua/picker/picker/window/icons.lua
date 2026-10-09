local M = {}

---Resolve once per view, allowing later invocations to discover newly loaded providers.
---@param override? false|fun(path: string): string?, string?
---@return fun(path: string): string?, string?
function M.resolve(override)
  if override == false then
    return function()
      return nil, nil
    end
  end

  if override ~= nil then
    if type(override) ~= 'function' then
      error('picker: view.icon must be false or a function', 0)
    end
    return function(path)
      local icon, highlight = override(path)
      if icon ~= nil and (type(icon) ~= 'string' or icon:find('[\r\n\t]')) then
        error('picker: view.icon must return a single-line string or nil', 0)
      end
      if highlight ~= nil and type(highlight) ~= 'string' then
        error('picker: view.icon highlight must be a string or nil', 0)
      end
      return icon, highlight
    end
  end

  local mini = rawget(_G, 'MiniIcons')
  if mini and type(mini.get) == 'function' then
    return function(path)
      local icon, highlight = mini.get('file', path)
      return icon, highlight
    end
  end

  local ok, devicons = pcall(require, 'nvim-web-devicons')
  if ok then
    return function(path)
      return devicons.get_icon(
        vim.fs.basename(path),
        vim.fn.fnamemodify(path, ':e'),
        { default = true }
      )
    end
  end

  return function()
    return nil, nil
  end
end

return M
