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
end)

suite:add("table.insert", function()
  local t = {}
  for i = 1, 200 do
    table.insert(t, i)
  end
end)

suite:add("rawset", function()
  local t = {}
  for i = 1, 200 do
    rawset(t, i, i)
  end
end)

return suite
