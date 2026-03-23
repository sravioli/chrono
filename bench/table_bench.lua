local chrono = require "chrono"

local suite = chrono.suite("Table Operations", {
  iterations = 500,
  warmup = 100,
})

suite:add("append (#t + 1)", function()
  local t = {}
  for i = 1, 200 do
    t[#t + 1] = i
  end
  local _ = t[200]
end)

suite:add("table.insert", function()
  local t = {}
  for i = 1, 200 do
    table.insert(t, i)
  end
  local _ = t[200]
end)

suite:add("rawset", function()
  local t = {}
  for i = 1, 200 do
    rawset(t, i, i)
  end
  local _ = t[200]
end)

return suite
