local M = {}

---Optional snippet parsing never opens source buffers or runs FileType hooks.
---@param path string
---@param text string
---@return picker.picker.TextHighlight[]
function M.highlights(path, text)
  if text == '' then
    return {}
  end
  local ft = vim.filetype.match({ filename = path })
  local lang = ft and vim.treesitter.language.get_lang(ft)
  if not lang then
    return {}
  end
  local available, parser = pcall(vim.treesitter.get_string_parser, text, lang)
  if not available or not parser then
    return {}
  end
  local highlights = {}
  local ok = pcall(function()
    parser:parse(true)
    parser:for_each_tree(function(tree, language_tree)
      local language = language_tree:lang()
      local query = vim.treesitter.query.get(language, 'highlights')
      if not query then
        return
      end
      for capture, node in query:iter_captures(tree:root(), text, 0, 1) do
        local name = query.captures[capture]
        local row, first, last_row, last = node:range()
        if last_row > 0 then
          last = #text
        end
        last = math.min(last, #text)
        if row == 0 and last > first and name ~= 'spell' and name ~= 'conceal' then
          highlights[#highlights + 1] = {
            first = first,
            last = last,
            group = '@' .. name .. '.' .. language,
            priority = 100,
          }
        end
      end
    end)
  end)
  -- Query errors must release the parser just like successful rendering.
  parser:destroy()
  return ok and highlights or {}
end

return M
