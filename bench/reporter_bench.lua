local chrono = require "chrono"
local json_reporter = require "chrono.reporters.json"
local pretty_reporter = require "chrono.reporters.pretty"
local text_reporter = require "chrono.reporters.text"

-- Build a realistic result set to format
local function make_result()
  return {
    suite_name = "Bench Reporter",
    runtime = "Lua",
    runtime_version = _VERSION,
    timer_source = "os.clock",
    benchmarks = {
      {
        name = "fast op",
        n = 1000,
        mean = 1.2e-7,
        stddev = 3.5e-8,
        min = 8.0e-8,
        max = 5.0e-7,
        median = 1.1e-7,
        p95 = 2.5e-7,
        p99 = 4.0e-7,
        ops_sec = 1 / 1.2e-7,
        total_time = 1.2e-4,
      },
      {
        name = "medium op",
        n = 1000,
        mean = 5.4e-4,
        stddev = 2.1e-5,
        min = 5.0e-4,
        max = 6.5e-4,
        median = 5.3e-4,
        p95 = 5.8e-4,
        p99 = 6.2e-4,
        ops_sec = 1 / 5.4e-4,
        total_time = 0.54,
      },
      {
        name = "slow op",
        n = 100,
        mean = 1.2e-2,
        stddev = 8.0e-4,
        min = 1.1e-2,
        max = 1.5e-2,
        median = 1.2e-2,
        p95 = 1.35e-2,
        p99 = 1.45e-2,
        ops_sec = 1 / 1.2e-2,
        total_time = 1.2,
      },
    },
  }
end

local results = make_result()
local devnull = chrono.devnull

local suite = chrono.suite("Reporters", {
  iterations = 500,
  warmup = 100,
})

suite:add("text format", function()
  text_reporter.format(results)
end)

suite:add("pretty format", function()
  pretty_reporter.format(results)
end)

suite:add("json format", function()
  json_reporter.format(results)
end)

return suite
