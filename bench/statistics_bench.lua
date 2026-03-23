local chrono = require "chrono"
local statistics = require "chrono.statistics"

-- Pre-generate sample arrays of various sizes
local function make_samples(n)
  local t = {}
  for i = 1, n do
    t[i] = math.random() * 0.001 -- 0–1ms range
  end
  return t
end

local samples_100 = make_samples(100)
local samples_1k = make_samples(1000)
local samples_10k = make_samples(10000)

local suite = chrono.suite("Statistics", {
  iterations = 500,
  warmup = 100,
})

suite:add("compute (100 samples)", function()
  statistics.compute(samples_100)
end)

suite:add("compute (1k samples)", function()
  statistics.compute(samples_1k)
end)

suite:add("compute (10k samples)", function()
  statistics.compute(samples_10k)
end)

return suite
