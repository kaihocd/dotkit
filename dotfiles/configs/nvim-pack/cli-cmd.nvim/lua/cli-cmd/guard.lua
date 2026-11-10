---One error convention for the whole plugin: every message carries the module
---path it came from, and the error level points at the caller's caller so a guard
---never hides where the bad value was.
---
---A module creates its own guard once, naming itself exactly as it is required:
---
---```lua
---local check = require('cli-cmd.guard')('cli-cmd.task')
---check(type(value) == 'string', 'value must be a string')
---```
---@param namespace string
---@return fun(condition: any, message: string)
return function(namespace)
  return function(condition, message)
    if not condition then
      error(namespace .. ': ' .. message, 3)
    end
  end
end
