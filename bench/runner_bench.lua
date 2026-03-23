local chrono = require "chrono"
local runner = require "chrono.runner"

local suite = chrono.suite("Runner Overhead", {
  iterations = 200,
  warmup = 50,
})

-- Measure the overhead of run_single with a no-op function
local function noop() end

suite:add("run_single (noop, 10 iters)", function()
  runner.run_single("noop", noop, { iterations = 10, warmup = 0 })
end)

suite:add("run_single (noop, 100 iters)", function()
  runner.run_single("noop", noop, { iterations = 100, warmup = 0 })
end)

suite:add("run_single (noop, 10 iters + warmup)", function()
  runner.run_single("noop", noop, { iterations = 10, warmup = 5 })
end)

suite:add("run_single (noop, batch=10)", function()
  runner.run_single("noop", noop, { iterations = 10, warmup = 0, batch_size = 10 })
end)

return suite
