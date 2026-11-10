return function(test)
  ---The error prefix a module passes to its guard must be the path it is
  ---required by, so the string a user sees in an error leads back to the file
  ---that raised it. Enforcing the rule mechanically is cheaper than remembering
  ---it: `backend/process.lua` may not call itself `cli-cmd.process`, and a file
  ---that moves must take its prefix with it.
  test('every guard names the module it lives in', function()
    local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
    local offenders = {}
    for _, path in ipairs(vim.fn.globpath(root .. '/lua', '**/*.lua', false, true)) do
      local relative = path:sub(#root + 6) -- drop `<root>/lua/`
      local expected = relative:gsub('%.lua$', ''):gsub('/init$', ''):gsub('/', '.')
      for _, line in ipairs(vim.fn.readfile(path)) do
        local declared = line:match("^local check = require%('cli%-cmd%.guard'%)%('([^']+)'%)")
        if declared ~= nil and declared ~= expected then
          offenders[#offenders + 1] = relative
            .. ': '
            .. declared
            .. ' (expected '
            .. expected
            .. ')'
        end
      end
    end
    assert(#offenders == 0, table.concat(offenders, '\n'))
  end)

  test('prefixes the message and reports the failing call site', function()
    local check = require('cli-cmd.guard')('cli-cmd.test')
    local function validate(value)
      check(type(value) == 'string', 'value must be a string')
    end
    local function install(value)
      -- Not a tail call: a tail call would replace this frame, and the guard's
      -- extra level exists to point at exactly this caller.
      local result = validate(value)
      return result
    end

    local ok, err = pcall(install, 5)
    local message = tostring(err)
    assert(not ok)
    assert(message:find('cli%-cmd%.test: value must be a string'), message)
    -- The level skips the helper and the guard, so the trace names the caller,
    -- not the file that phrased the rule.
    assert(message:find('test_guard%.lua:%d+:'), message)
    assert(not message:find('guard%.lua:', 1, true), message)

    assert(pcall(check, true, 'unused'))
  end)
end
