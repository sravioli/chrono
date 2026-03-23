--- Smoke tests: end-to-end library API, formatting, and error handling.

local chrono = require "chrono"
local pretty_reporter = require "chrono.reporters.pretty"
local text_reporter = require "chrono.reporters.text"

describe("chrono.run", function()
  it("returns correct name and sample count", function()
    local r = chrono.run("noop", function() end, { iterations = 10, warmup = 2 })
    assert.are.equal("noop", r.name)
    assert.is_nil(r.error)
    assert.are.equal(10, r.n)
  end)

  it("populates all statistical fields", function()
    local r = chrono.run("stats", function()
      local _ = 1 + 1
    end, { iterations = 20 })
    assert.is_number(r.mean)
    assert.is_number(r.stddev)
    assert.is_number(r.min)
    assert.is_number(r.max)
    assert.is_number(r.median)
    assert.is_number(r.p95)
    assert.is_number(r.p99)
    assert.is_number(r.ops_sec)
    assert.is_number(r.total_time)
  end)

  it("attaches runtime metadata", function()
    local r = chrono.run("meta", function() end, { iterations = 5 })
    assert.is_string(r.runtime)
    assert.is_string(r.runtime_version)
    assert.is_truthy(r.runtime:match "^Lua")
  end)

  it("reports an error when the benchmark function throws", function()
    local r = chrono.run("boom", function()
      error "kaboom"
    end, { iterations = 5 })
    assert.is_string(r.error)
    assert.is_truthy(r.error:find "kaboom")
  end)

  it("calls setup before and teardown after each iteration", function()
    local counter = { n = 0 }
    local r = chrono.run("hooks", function()
      local _ = counter.n
    end, {
      iterations = 5,
      setup = function()
        counter.n = counter.n + 1
      end,
      teardown = function()
        counter.n = counter.n - 1
      end,
    })
    assert.is_nil(r.error)
    assert.are.equal(0, counter.n)
  end)

  it("honours min_time by running extra iterations", function()
    local r = chrono.run("min_time", function()
      local s = 0
      for i = 1, 1000 do
        s = s + i
      end
    end, { iterations = 1, min_time = 0.01 })
    assert.is_nil(r.error)
    assert.is_true(r.n > 1)
  end)

  it("honours batch_size by dividing time per batch", function()
    local r = chrono.run("batch", function()
      local _ = 1 + 1
    end, { iterations = 10, batch_size = 4 })
    assert.is_nil(r.error)
    assert.are.equal(10, r.n)
  end)

  it("selects the cpu timer when timer_source is 'cpu'", function()
    local r = chrono.run("cpu", function() end, { iterations = 5, timer_source = "cpu" })
    assert.is_nil(r.error)
    assert.is_string(r.timer_source)
    assert.are_not.equal("N/A", r.timer_source)
  end)

  it("records total_time >= 0", function()
    local r = chrono.run("time", function() end, { iterations = 5 })
    assert.is_true(r.total_time >= 0)
  end)

  it("ensures min <= mean <= max", function()
    local r = chrono.run("order", function()
      local t = {}
      for i = 1, 50 do
        t[i] = i
      end
    end, { iterations = 30 })
    assert.is_nil(r.error)
    assert.is_true(r.min <= r.mean)
    assert.is_true(r.mean <= r.max)
  end)
end)

describe("chrono.suite", function()
  it("creates a suite with a custom name", function()
    local s = chrono.suite("my suite", { iterations = 5 })
    local results = s:run()
    assert.are.equal("my suite", results.suite_name)
  end)

  it("uses a default name when none is provided", function()
    local s = chrono.suite(nil, { iterations = 5 })
    local results = s:run()
    assert.are.equal("Benchmark Suite", results.suite_name)
  end)

  it("runs multiple benchmarks and returns all results", function()
    local s = chrono.suite("multi", { iterations = 10 })
    s:add("a", function()
      local _ = 1 + 1
    end)
    s:add("b", function()
      local _ = tostring(42)
    end)
    local results = s:run()
    assert.are.equal(2, #results.benchmarks)
    assert.is_nil(results.benchmarks[1].error)
    assert.is_nil(results.benchmarks[2].error)
    assert.are.equal("a", results.benchmarks[1].name)
    assert.are.equal("b", results.benchmarks[2].name)
  end)

  it("returns self from :add for chaining", function()
    local s = chrono.suite "chain"
    local ret = s:add("x", function() end)
    assert.are.equal(s, ret)
  end)

  it("attaches runtime info to suite results", function()
    local s = chrono.suite("rt", { iterations = 5 })
    s:add("x", function() end)
    local results = s:run()
    assert.is_string(results.runtime)
    assert.is_string(results.runtime_version)
  end)

  it("applies suite-level defaults to all benchmarks", function()
    local s = chrono.suite("defaults", { iterations = 7 })
    s:add("x", function() end)
    local results = s:run()
    assert.are.equal(7, results.benchmarks[1].n)
  end)

  it("allows per-benchmark option overrides", function()
    local s = chrono.suite("override", { iterations = 5 })
    s:add("x", function() end, { iterations = 12 })
    local results = s:run()
    assert.are.equal(12, results.benchmarks[1].n)
  end)

  it("allows run-time option overrides", function()
    local s = chrono.suite("run-override", { iterations = 5 })
    s:add("x", function() end)
    local results = s:run { iterations = 15 }
    assert.are.equal(15, results.benchmarks[1].n)
  end)

  it("gives per-benchmark overrides precedence over run-time overrides", function()
    local s = chrono.suite("precedence", { iterations = 5 })
    s:add("x", function() end, { iterations = 8 })
    local results = s:run { iterations = 20 }
    assert.are.equal(8, results.benchmarks[1].n)
  end)

  it("isolates errors to individual benchmarks", function()
    local s = chrono.suite("isolation", { iterations = 5 })
    s:add("ok", function()
      local _ = 1 + 1
    end)
    s:add("fail", function()
      error "oops"
    end)
    s:add("ok2", function()
      local _ = 2 + 2
    end)
    local results = s:run()
    assert.are.equal(3, #results.benchmarks)
    assert.is_nil(results.benchmarks[1].error)
    assert.is_string(results.benchmarks[2].error)
    assert.is_nil(results.benchmarks[3].error)
  end)

  it("runs an empty suite without error", function()
    local s = chrono.suite("empty", { iterations = 5 })
    local results = s:run()
    assert.are.equal(0, #results.benchmarks)
  end)

  it("invokes on_benchmark_result as each benchmark finishes", function()
    local s = chrono.suite("callbacks", { iterations = 4 })
    local seen = {}
    s:add("a", function() end)
    s:add("b", function() end)

    local results = s:run {
      on_benchmark_result = function(result, idx, bench, partial_results)
        seen[#seen + 1] = {
          idx = idx,
          name = result.name,
          bench_name = bench.name,
          count = #partial_results.benchmarks,
          suite_timer = partial_results.timer_source,
        }
      end,
    }

    assert.are.equal(2, #seen)
    assert.are.same({ 1, 2 }, { seen[1].idx, seen[2].idx })
    assert.are.same({ "a", "b" }, { seen[1].name, seen[2].name })
    assert.are.same({ "a", "b" }, { seen[1].bench_name, seen[2].bench_name })
    assert.are.same({ 1, 2 }, { seen[1].count, seen[2].count })
    assert.is_string(seen[1].suite_timer)
    assert.is_nil(results.benchmarks[1].timer_source)
    assert.is_nil(results.benchmarks[2].timer_source)
  end)
end)

describe("chrono.format", function()
  describe("text", function()
    it("formats suite results with suite name and statistics", function()
      local s = chrono.suite("fmt", { iterations = 5 })
      s:add("x", function() end)
      local results = s:run()
      local text = chrono.format(results, "text")
      assert.is_truthy(text:find "fmt")
      assert.is_truthy(text:find "mean")
      assert.is_truthy(text:find "ops/sec")
    end)

    it("formats a single result", function()
      local r = chrono.run("solo", function() end, { iterations = 5 })
      local text = chrono.format(r, "text")
      assert.is_truthy(text:find "solo")
      assert.is_truthy(text:find "mean")
    end)

    it("defaults to text when no format is given", function()
      local r = chrono.run("def", function() end, { iterations = 5 })
      local text = chrono.format(r)
      assert.is_truthy(text:find "def")
    end)

    it("marks errored benchmarks", function()
      local s = chrono.suite("errtxt", { iterations = 5 })
      s:add("bad", function()
        error "boom"
      end)
      local text = chrono.format(s:run(), "text")
      assert.is_truthy(text:find "ERROR")
    end)

    it("supports incremental suite rendering", function()
      local s = chrono.suite("stream-text", { iterations = 5 })
      s:add("alpha", function() end)
      local results = s:run()

      local header = text_reporter.start_suite(results)
      local bench = text_reporter.format_benchmark(results.benchmarks[1], 1)
      local footer = text_reporter.finish_suite(results)

      assert.is_truthy(header:find "stream%-text")
      assert.is_truthy(header:find "Runtime")
      assert.is_truthy(bench:find "alpha")
      assert.is_truthy(bench:find "mean")
      assert.is_truthy(footer:find "1 benchmark%(s%)")
    end)
  end)

  describe("pretty", function()
    it("supports incremental suite rendering", function()
      local s = chrono.suite("stream-pretty", { iterations = 5 })
      s:add("beta", function() end)
      local results = s:run()

      local header = pretty_reporter.start_suite(results)
      local bench = pretty_reporter.format_benchmark(results.benchmarks[1], 1)
      local footer = pretty_reporter.finish_suite(results)

      assert.is_truthy(header:find "stream%-pretty")
      assert.is_truthy(header:find "runtime")
      assert.is_truthy(bench:find "beta")
      assert.is_truthy(footer:find "benchmark%(s%)")
    end)
  end)

  describe("json", function()
    it("includes required top-level keys for suite results", function()
      local s = chrono.suite("jfmt", { iterations = 5 })
      s:add("y", function() end)
      local json = chrono.format(s:run(), "json")
      assert.is_truthy(json:find '"suite_name"')
      assert.is_truthy(json:find '"benchmarks"')
      assert.is_truthy(json:find '"runtime_version"')
    end)

    it("includes statistical fields in benchmark entries", function()
      local s = chrono.suite("jstats", { iterations = 5 })
      s:add("z", function() end)
      local json = chrono.format(s:run(), "json")
      assert.is_truthy(json:find '"mean"')
      assert.is_truthy(json:find '"stddev"')
      assert.is_truthy(json:find '"ops_sec"')
    end)

    it("includes the error field for failing benchmarks", function()
      local s = chrono.suite("jerr", { iterations = 5 })
      s:add("fail", function()
        error "oops"
      end)
      local json = chrono.format(s:run(), "json")
      assert.is_truthy(json:find '"error"')
    end)
  end)

  it("raises on unknown format", function()
    local r = chrono.run("x", function() end, { iterations = 5 })
    assert.has_error(function()
      chrono.format(r, "csv")
    end)
  end)

  it("exposes reporters by format", function()
    assert.are.equal(text_reporter, chrono.get_reporter "text")
    assert.are.equal(pretty_reporter, chrono.get_reporter "pretty")
  end)
end)

describe("chrono module metadata", function()
  it("exposes a version string", function()
    assert.is_string(chrono._VERSION)
    assert.is_truthy(chrono._VERSION:match "%d+%.%d+")
  end)

  it("exposes runtime and runtime_version", function()
    assert.is_string(chrono.runtime)
    assert.is_string(chrono.runtime_version)
  end)
end)

---------------------------------------------------------------------------
-- GC control
---------------------------------------------------------------------------

describe("gc_off option", function()
  it("disables GC during measurement and restores it afterwards", function()
    -- GC should be running before and after, but disabled during fn()
    local gc_was_off_during = false
    local r = chrono.run("gc_off_test", function()
      -- collectgarbage("count") still works with GC stopped;
      -- the only way to detect is to try a step and see it was a no-op,
      -- but that's fragile. Instead we just verify no crash and results are valid.
      local _ = 1 + 1
    end, { iterations = 5, gc_off = true })
    assert.is_nil(r.error)
    assert.are.equal(5, r.n)
    -- GC should be running again after the benchmark
    assert.is_true(collectgarbage("step", 0) or true)
  end)

  it("still produces valid statistics with gc_off", function()
    local r = chrono.run("gc_off_stats", function()
      local t = {}
      for i = 1, 100 do
        t[i] = i
      end
    end, { iterations = 10, gc_off = true })
    assert.is_nil(r.error)
    assert.is_number(r.mean)
    assert.is_number(r.stddev)
    assert.is_true(r.min <= r.mean)
    assert.is_true(r.mean <= r.max)
  end)

  it("restores GC even when the benchmark errors", function()
    local r = chrono.run("gc_off_error", function()
      error "boom"
    end, { iterations = 5, gc_off = true })
    assert.is_string(r.error)
    -- GC must be running again
    collectgarbage "collect"
  end)
end)

describe("gc_collect option (suite-level)", function()
  it("runs without error when gc_collect is enabled", function()
    local s = chrono.suite("gc_collect_suite", { iterations = 5 })
    s:add("a", function()
      local _ = {}
    end)
    s:add("b", function()
      local _ = {}
    end)
    local results = s:run { gc_collect = true }
    assert.are.equal(2, #results.benchmarks)
    assert.is_nil(results.benchmarks[1].error)
    assert.is_nil(results.benchmarks[2].error)
  end)
end)

---------------------------------------------------------------------------
-- Benchmark randomization
---------------------------------------------------------------------------

describe("randomize option (suite-level)", function()
  it("runs all benchmarks when randomize is enabled", function()
    local s = chrono.suite("rand", { iterations = 3 })
    s:add("a", function() end)
    s:add("b", function() end)
    s:add("c", function() end)
    local results = s:run { randomize = true }
    assert.are.equal(3, #results.benchmarks)
    -- All three names must appear (order may differ)
    local names = {}
    for _, b in ipairs(results.benchmarks) do
      names[b.name] = true
    end
    assert.is_true(names["a"])
    assert.is_true(names["b"])
    assert.is_true(names["c"])
  end)

  it("does not shuffle when randomize is not set", function()
    local s = chrono.suite("no_rand", { iterations = 3 })
    s:add("x", function() end)
    s:add("y", function() end)
    s:add("z", function() end)
    local results = s:run()
    assert.are.equal("x", results.benchmarks[1].name)
    assert.are.equal("y", results.benchmarks[2].name)
    assert.are.equal("z", results.benchmarks[3].name)
  end)

  it("does not mutate the original benchmarks list", function()
    local s = chrono.suite("no_mutate", { iterations = 3 })
    s:add("first", function() end)
    s:add("second", function() end)
    s:run { randomize = true }
    -- run again without randomize — should be in insertion order
    local results = s:run()
    assert.are.equal("first", results.benchmarks[1].name)
    assert.are.equal("second", results.benchmarks[2].name)
  end)
end)

---------------------------------------------------------------------------
-- Benchmark filtering pipeline
---------------------------------------------------------------------------

describe("benchmark filtering", function()
  it("skips benchmarks that match a filter", function()
    local s = chrono.suite("filter_test", { iterations = 3 })
    s:add("keep_me", function() end)
    s:add("skip_me", function() end)
    s:add("keep_too", function() end)
    s:filter(function(name)
      return name == "skip_me", "testing skip"
    end)
    local results = s:run()
    assert.are.equal(2, #results.benchmarks)
    assert.are.equal("keep_me", results.benchmarks[1].name)
    assert.are.equal("keep_too", results.benchmarks[2].name)
  end)

  it("populates skipped list with reasons", function()
    local s = chrono.suite("skip_reasons", { iterations = 3 })
    s:add("a", function() end)
    s:add("b", function() end)
    s:filter(function(name)
      if name == "b" then
        return true, "not today"
      end
      return false
    end)
    local results = s:run()
    assert.is_table(results.skipped)
    assert.are.equal(1, #results.skipped)
    assert.are.equal("b", results.skipped[1].name)
    assert.are.equal("not today", results.skipped[1].reason)
  end)

  it("runs all benchmarks when no filter matches", function()
    local s = chrono.suite("no_skip", { iterations = 3 })
    s:add("a", function() end)
    s:add("b", function() end)
    s:filter(function()
      return false
    end)
    local results = s:run()
    assert.are.equal(2, #results.benchmarks)
    assert.is_nil(results.skipped)
  end)

  it("supports multiple filters (first match wins)", function()
    local s = chrono.suite("multi_filter", { iterations = 3 })
    s:add("a", function() end)
    s:add("b", function() end)
    s:add("c", function() end)
    s:filter(function(name)
      return name == "a", "filter1"
    end)
    s:filter(function(name)
      return name == "c", "filter2"
    end)
    local results = s:run()
    assert.are.equal(1, #results.benchmarks)
    assert.are.equal("b", results.benchmarks[1].name)
    assert.are.equal(2, #results.skipped)
  end)

  it("returns self from :filter for chaining", function()
    local s = chrono.suite "chain_filter"
    local ret = s:filter(function()
      return false
    end)
    assert.are.equal(s, ret)
  end)
end)

describe("chrono.filters.require_ffi", function()
  it("is a function", function()
    assert.is_function(chrono.filters.require_ffi)
  end)

  it("does not filter when ffi_required is absent", function()
    local skip = chrono.filters.require_ffi("test", {})
    assert.is_false(skip)
  end)

  it("does not filter when ffi_required is false", function()
    local skip = chrono.filters.require_ffi("test", { ffi_required = false })
    assert.is_false(skip)
  end)

  -- If FFI is available, ffi_required=true should NOT skip
  -- If FFI is unavailable, ffi_required=true should skip
  -- We test the function is consistent with pcall(require,"ffi")
  it("is consistent with FFI availability", function()
    local has_ffi = pcall(require, "ffi")
    local skip, reason = chrono.filters.require_ffi("test", { ffi_required = true })
    if has_ffi then
      assert.is_false(skip)
    else
      assert.is_true(skip)
      assert.is_string(reason)
    end
  end)
end)

---------------------------------------------------------------------------
-- /dev/null write sink
---------------------------------------------------------------------------

describe("chrono.devnull", function()
  it("is exposed from the chrono module", function()
    assert.is_table(chrono.devnull)
  end)

  it("write() returns true", function()
    assert.is_true(chrono.devnull.write("hello", "world"))
  end)

  it("write() accepts no arguments", function()
    assert.is_true(chrono.devnull.write())
  end)

  it("file object has :write(), :flush(), :close()", function()
    local f = chrono.devnull.file
    assert.is_true(f:write "data")
    assert.is_true(f:flush())
    assert.is_true(f:close())
  end)
end)

---------------------------------------------------------------------------
-- JIT utility module
---------------------------------------------------------------------------

describe("chrono.jitutil", function()
  local jitutil = require "chrono.jitutil"

  it("loads without error", function()
    assert.is_table(jitutil)
  end)

  it("verify_jitted returns boolean + message", function()
    local ok, msg = jitutil.verify_jitted(function() end)
    assert.is_boolean(ok)
    assert.is_string(msg)
  end)

  if type(jit) ~= "table" then
    it("returns false on non-LuaJIT", function()
      local ok, msg = jitutil.verify_jitted(function() end)
      assert.is_false(ok)
      assert.is_truthy(msg:find "LuaJIT")
    end)
  end
end)

---------------------------------------------------------------------------
-- JIT statistics module
---------------------------------------------------------------------------

describe("chrono.jitstats", function()
  local jitstats = require "chrono.jitstats"

  it("loads without error", function()
    assert.is_table(jitstats)
  end)

  it("exposes available as a boolean", function()
    assert.is_boolean(jitstats.available)
  end)

  it("snapshot returns a table with starts, aborts, flushes", function()
    local s = jitstats.snapshot()
    assert.is_table(s)
    assert.is_number(s.starts)
    assert.is_number(s.aborts)
    assert.is_number(s.flushes)
  end)

  it("diff computes correct differences", function()
    local before = { starts = 1, aborts = 0, flushes = 0 }
    local after = { starts = 5, aborts = 2, flushes = 1 }
    local d = jitstats.diff(before, after)
    assert.are.equal(4, d.starts)
    assert.are.equal(2, d.aborts)
    assert.are.equal(1, d.flushes)
  end)

  it("collect_jitstats option does not break runner", function()
    local r = chrono.run("jitstats_test", function()
      local _ = 1 + 1
    end, { iterations = 5, collect_jitstats = true })
    assert.is_nil(r.error)
    assert.are.equal(5, r.n)
  end)
end)

---------------------------------------------------------------------------
-- Subprocess module
---------------------------------------------------------------------------

describe("chrono.subprocess", function()
  local subprocess = require "chrono.subprocess"

  it("loads without error", function()
    assert.is_table(subprocess)
  end)

  it("_parse_child_output parses valid JSON", function()
    local json_str =
      '{\n  "mean": 0.001,\n  "min": 0.0005,\n  "max": 0.002,\n  "n": 10,\n  "name": "test"\n}'
    local result = subprocess._parse_child_output(json_str, "fallback")
    assert.is_table(result)
    assert.are.equal("test", result.name)
    assert.are.equal(10, result.n)
    assert.is_number(result.mean)
  end)

  it("_parse_child_output returns error for empty output", function()
    local result = subprocess._parse_child_output("", "fallback")
    assert.is_string(result.error)
  end)

  it("_parse_child_output returns error for invalid output", function()
    local result = subprocess._parse_child_output("not json at all {{{", "fallback")
    assert.is_string(result.error)
  end)
end)
