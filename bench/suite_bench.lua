local chrono = require "chrono"

local suite = chrono.suite("Suite API", {
  iterations = 500,
  warmup = 100,
})

local function noop() end

suite:add("suite creation", function()
  chrono.suite "bench"
end)

suite:add("suite creation + options", function()
  chrono.suite("bench", { iterations = 1000, warmup = 100, gc_off = true })
end)

suite:add("add 1 benchmark", function()
  local s = chrono.suite "bench"
  s:add("a", noop)
end)

suite:add("add 10 benchmarks", function()
  local s = chrono.suite "bench"
  for i = 1, 10 do
    s:add("b" .. i, noop)
  end
end)

suite:add("add + filter", function()
  local s = chrono.suite "bench"
  s:add("a", noop)
  s:add("b", noop)
  s:filter(function(name)
    return name == "b", "skip"
  end)
end)

return suite
