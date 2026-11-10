---The docs are part of the contract: they name modules and show code a reader
---will copy. Both rot silently, so check them the way the code is checked.
return function(test)
  local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
  local compile = loadstring or load

  local function read(path)
    assert(vim.fn.filereadable(path) == 1, 'missing doc: ' .. path)
    return table.concat(vim.fn.readfile(path), '\n')
  end

  local docs = {
    ['README.md'] = read(root .. '/README.md'),
    ['docs/api.md'] = read(root .. '/docs/api.md'),
  }

  test('every lua example in the docs compiles', function()
    local broken = {}
    for name, text in pairs(docs) do
      local index = 0
      for body in text:gmatch('```lua\n(.-)```') do
        index = index + 1
        local chunk, err = compile(body, name .. '#lua' .. index)
        if not chunk then
          broken[#broken + 1] = ('%s block %d: %s'):format(name, index, err)
        end
      end
    end
    assert(#broken == 0, table.concat(broken, '\n'))
  end)

  test('every module the docs require exists', function()
    local missing = {}
    for name, text in pairs(docs) do
      for module in text:gmatch([[require%(['"](cli%-cmd[%w%._%-]*)['"]%)]]) do
        local ok, err = pcall(require, module)
        if not ok then
          missing[#missing + 1] = ('%s requires %s: %s'):format(name, module, err)
        end
      end
    end
    assert(#missing == 0, table.concat(missing, '\n'))
  end)
end
