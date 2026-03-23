--- chrono: A pure Lua 5.1 / LuaJIT benchmarking engine.
--
-- Usage:
--   local chrono = require("chrono")
--   local suite = chrono.suite("My Suite", { iterations = 1000 })
--   suite:add("case A", function() ... end)
--   chrono.report(suite:run())

local devnull = require "chrono.devnull"
local json_reporter = require "chrono.reporters.json"
local pretty_reporter = require "chrono.reporters.pretty"
local runner = require "chrono.runner"
local text_reporter = require "chrono.reporters.text"
local timer = require "chrono.timer"

local M = {}

M._VERSION = "0.1.0"
M.runtime = timer.runtime
M.runtime_version = timer.runtime_version
M.filters = {}
M.devnull = devnull

---------------------------------------------------------------------------
-- Suite
---------------------------------------------------------------------------

local Suite = {}
Suite.__index = Suite

local function shuffle(t)
  for i = #t, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
end

--- Create a new benchmark suite.
-- @param name string  suite display name
-- @param opts table   default options applied to every benchmark
-- @return Suite
function M.suite(name, opts)
  return setmetatable({
    name = name or "Benchmark Suite",
    _benchmarks = {},
    _opts = opts or {},
  }, Suite)
end

--- Add a benchmark case to the suite.
-- @param name string
-- @param fn   function
-- @param opts table   per-benchmark overrides
-- @return Suite (for chaining)
function Suite:add(name, fn, opts)
  self._benchmarks[#self._benchmarks + 1] = {
    name = name,
    fn = fn,
    opts = opts,
  }
  return self
end

--- Add a filter function to the suite.
-- Filters are called with (name, opts) for each benchmark.  If a filter
-- returns true, reason the benchmark is skipped.
-- @param fn function(name, opts) -> boolean, string|nil
-- @return Suite (for chaining)
function Suite:filter(fn)
  if not self._filters then
    self._filters = {}
  end
  self._filters[#self._filters + 1] = fn
  return self
end

--- Execute all benchmarks and return a result table.
-- @param run_opts table  overrides on top of suite defaults
-- @return table
function Suite:run(run_opts)
  run_opts = run_opts or {}

  -- Config precedence: suite defaults < run-time overrides
  local merged = {}
  for k, v in pairs(self._opts) do
    merged[k] = v
  end
  for k, v in pairs(run_opts) do
    merged[k] = v
  end

  -- Extract suite-level options (not forwarded to runner)
  local randomize = merged.randomize
  local gc_collect = merged.gc_collect
  local out_of_process = merged.out_of_process
  local bench_file = merged.bench_file
  local on_benchmark_result = merged.on_benchmark_result
  merged.randomize = nil
  merged.gc_collect = nil
  merged.out_of_process = nil
  merged.bench_file = nil
  merged.on_benchmark_result = nil

  -- Build ordered list of benchmarks, applying filters
  local order = {}
  local skipped = {}
  for i = 1, #self._benchmarks do
    local b = self._benchmarks[i]
    local skip = false
    if self._filters then
      for _, flt in ipairs(self._filters) do
        local filtered, reason = flt(b.name, b.opts)
        if filtered then
          skipped[#skipped + 1] = { name = b.name, reason = reason or "filtered" }
          skip = true
          break
        end
      end
    end
    if not skip then
      order[#order + 1] = b
    end
  end
  if randomize then
    math.randomseed(os.clock() * 1e6)
    shuffle(order)
  end

  local results = {
    suite_name = self.name,
    runtime = timer.runtime,
    runtime_version = timer.runtime_version,
    benchmarks = {},
    skipped = #skipped > 0 and skipped or nil,
  }

  for _, b in ipairs(order) do
    -- Config precedence: merged < per-benchmark overrides
    local bopts = {}
    for k, v in pairs(merged) do
      bopts[k] = v
    end
    if b.opts then
      for k, v in pairs(b.opts) do
        bopts[k] = v
      end
    end

    local result
    if out_of_process and bench_file then
      local subprocess = require "chrono.subprocess"
      result = subprocess.run_single(b.name, bench_file, b.name, bopts)
    else
      result = runner.run_single(b.name, b.fn, bopts)
    end

    if not results.timer_source and result.timer_source then
      results.timer_source = result.timer_source
    end

    results.benchmarks[#results.benchmarks + 1] = result

    if on_benchmark_result then
      on_benchmark_result(result, #results.benchmarks, b, results)
    end

    result.timer_source = nil

    if gc_collect then
      collectgarbage "collect"
    end
  end

  return results
end

---------------------------------------------------------------------------
-- Convenience helpers
---------------------------------------------------------------------------

--- Run a single benchmark (outside of a suite).
-- @param name string
-- @param fn   function
-- @param opts table
-- @return table  statistics or error
function M.run(name, fn, opts)
  local r = runner.run_single(name, fn, opts)
  r.runtime = timer.runtime
  r.runtime_version = timer.runtime_version
  return r
end

local reporters = { text = text_reporter, json = json_reporter, pretty = pretty_reporter }

function M.get_reporter(fmt)
  fmt = fmt or "text"
  local rpt = reporters[fmt]
  if not rpt then
    error("chrono: unknown format '" .. tostring(fmt) .. "'")
  end
  return rpt
end

--- Format results as a string.
-- @param results table
-- @param fmt     string "text"|"json" (default "text")
-- @return string
function M.format(results, fmt)
  local rpt = M.get_reporter(fmt)
  return rpt.format(results)
end

--- Format and print results to stdout.
function M.report(results, fmt)
  io.write(M.format(results, fmt))
  io.write "\n"
end

---------------------------------------------------------------------------
-- Built-in filters
---------------------------------------------------------------------------

local has_ffi = pcall(require, "ffi")

--- Built-in filter: skip benchmarks with opts.ffi_required = true when FFI is
--- unavailable.
-- @param name string
-- @param opts table|nil
-- @return boolean, string|nil
function M.filters.require_ffi(_, opts)
  if opts and opts.ffi_required and not has_ffi then
    return true, "FFI unavailable"
  end
  return false
end

return M
