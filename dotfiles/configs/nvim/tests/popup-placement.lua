local place = require('popup.layout.placement').below_or_above
local size = { width = 20, height = 8, min_height = 4 }
local viewport = { width = 80, height = 24 }
assert(vim.deep_equal(place(size, { row = 2, col = 10 }, viewport), {
  row = 3,
  col = 10,
  width = 20,
  height = 8,
}))
assert(vim.deep_equal(place(size, { row = 22, col = 75 }, viewport), {
  row = 14,
  col = 60,
  width = 20,
  height = 8,
}))
assert(vim.deep_equal(place(size, { row = 4, col = 0 }, { width = 10, height = 10 }), {
  row = 5,
  col = 0,
  width = 10,
  height = 5,
}))
assert(vim.deep_equal(place(size, { row = 0, col = 0 }, { width = 1, height = 1 }), {
  row = 0,
  col = 0,
  width = 1,
  height = 1,
}))
for height = 1, 30 do
  for row = -1, height do
    local result = place(size, { row = row, col = 100 }, { width = 12, height = height })
    assert(result.row >= 0 and result.col >= 0)
    assert(result.row + result.height <= height)
    assert(result.col + result.width <= 12)
    assert(result.height >= 1 and result.width >= 1)
  end
end
assert(size.height == 8 and viewport.height == 24)
print('PASS popup placement')
