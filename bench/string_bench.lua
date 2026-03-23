local chrono = require "chrono"

local suite = chrono.suite("String Operations", {
  iterations = 200,
  warmup = 50,
})

suite:add("string.rep", function()
  local _ = string.rep("x", 100)
end)

suite:add("concatenation", function()
  local s = ""
  for _ = 1, 100 do
    s = s .. "x"
  end
end)

suite:add("table.concat", function()
  local t = {}
  for i = 1, 100 do
    t[i] = "x"
  end
  local _ = table.concat(t)
end)

return suite
