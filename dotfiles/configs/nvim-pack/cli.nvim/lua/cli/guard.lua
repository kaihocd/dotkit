---One error convention for the whole plugin: a namespace prefix on every message
---and a level that points at the caller's caller, so a guard never hides where
---the bad value came from. Modules create their own guard once:
---
---```lua
---local check = require('cli.guard')('cli.task')
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
