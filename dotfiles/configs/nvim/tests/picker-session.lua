local session = require('plugins.explorer.picker.session')
local scheduled, deferred = {}, {}
local lifecycle = session.new(function(callback)
  scheduled[#scheduled + 1] = callback
end, function(_, callback)
  deferred[#deferred + 1] = callback
end)
local calls = 0
lifecycle.schedule(function()
  calls = calls + 1
end)
lifecycle.defer(10, function()
  calls = calls + 10
end)
assert(#scheduled == 1 and #deferred == 1)
lifecycle.invalidate()
scheduled[1]()
deferred[1]()
assert(calls == 0, 'Invalidated work must not run')
lifecycle.schedule(function()
  calls = calls + 1
end)
lifecycle.close()
scheduled[2]()
assert(calls == 0, 'Closed sessions must reject scheduled work')
assert(not lifecycle.schedule(function()
  calls = calls + 100
end))
assert(not lifecycle.defer(1, function()
  calls = calls + 100
end))
lifecycle.close()
assert(lifecycle.is_closed())
print('PASS picker session lifecycle')
