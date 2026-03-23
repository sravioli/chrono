local chrono = require "chrono"
local timer = require "chrono.timer"

local suite = chrono.suite("Timer", {
  iterations = 1000,
  warmup = 200,
})

local wall_clock = timer.resolve "wall"
local cpu_clock = timer.resolve "cpu"

suite:add("wall clock call", function()
  wall_clock()
end)

suite:add("cpu clock call", function()
  cpu_clock()
end)

suite:add("wall clock pair (t1-t0)", function()
  local t0 = wall_clock()
  local _ = wall_clock() - t0
end)

return suite
