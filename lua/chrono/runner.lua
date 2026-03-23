--- chrono.runner: Benchmark execution engine.

local jitutil = require "chrono.jitutil"
local statistics = require "chrono.statistics"
local timer = require "chrono.timer"

local M = {}

local is_luajit = timer.is_luajit

-- Cache: once we've verified a clock function we don't re-verify it.
local verified_clocks = {}

local function ensure_clock_jitted(clock)
  if not is_luajit or verified_clocks[clock] then
    return
  end
  verified_clocks[clock] = true
  jitutil.verify_jitted(clock)
end

local DEFAULTS = {
  iterations = 100,
  warmup = 0,
  min_time = 0,
  batch_size = 1,
  timer_source = "wall",
  setup = nil,
  teardown = nil,
  gc_off = false,
}

local function merge(base, over)
  local t = {}
  for k, v in pairs(base) do
    t[k] = v
  end
  if over then
    for k, v in pairs(over) do
      t[k] = v
    end
  end
  return t
end

local function err_result(name, msg, src)
  return { name = name, error = tostring(msg), timer_source = src or "N/A" }
end

--- Execute a single benchmark and return its result.
-- @param name string   display name
-- @param fn   function to benchmark (no args, no return)
-- @param opts table    option overrides
-- @return table        statistics or error
function M.run_single(name, fn, opts)
  opts = merge(DEFAULTS, opts)

  local clock, clock_src = timer.resolve(opts.timer_source)
  ensure_clock_jitted(clock)
  local iterations = opts.iterations
  local warmup = opts.warmup
  local min_time = opts.min_time
  local batch = opts.batch_size
  local setup = opts.setup
  local teardown = opts.teardown
  local gc_off = opts.gc_off
  local collect_jitstats = opts.collect_jitstats

  -- Optional JIT statistics collector
  local jitstats_mod
  if collect_jitstats then
    jitstats_mod = require "chrono.jitstats"
    if not jitstats_mod.available then
      jitstats_mod = nil
    end
  end

  -- 1. Validate (single pcall probe)
  local ok, ve = pcall(fn)
  if not ok then
    return err_result(name, "validation failed: " .. tostring(ve), clock_src)
  end

  -- 2. Warmup (remaining; 1 iteration already executed above)
  if warmup > 1 then
    local wok, we = pcall(function()
      for _ = 2, warmup do
        fn()
      end
    end)
    if not wok then
      return err_result(name, "warmup error: " .. tostring(we), clock_src)
    end
  end

  -- 3. Reset JIT hot counters so prior benchmarks don't influence this one
  if is_luajit and jit then
    jit.off()
    jit.on()
  end

  -- 4. Optionally disable GC during measurement
  if gc_off then
    collectgarbage "collect"
    collectgarbage "stop"
  end

  -- 5. Optionally start JIT stats collection
  if jitstats_mod then
    jitstats_mod.start()
    jitstats_mod.reset()
  end

  -- 6. Measurement
  local samples = {}
  local total_time = 0
  local count = 0
  local jit_samples

  if jitstats_mod then
    jit_samples = {}
  end

  local mok, me = pcall(function()
    while count < iterations or (min_time > 0 and total_time < min_time) do
      if setup then
        setup()
      end

      local snap_before
      if jitstats_mod then
        snap_before = jitstats_mod.snapshot()
      end

      local t0 = clock()
      if batch > 1 then
        for _ = 1, batch do
          fn()
        end
      else
        fn()
      end
      local t1 = clock()

      if teardown then
        teardown()
      end

      count = count + 1
      samples[count] = (t1 - t0) / batch
      total_time = total_time + (t1 - t0)

      if jitstats_mod then
        jit_samples[count] = jitstats_mod.diff(snap_before, jitstats_mod.snapshot())
      end
    end
  end)

  -- Stop JIT stats collection
  if jitstats_mod then
    jitstats_mod.stop()
  end

  -- Restore GC if it was disabled
  if gc_off then
    collectgarbage "restart"
  end

  if not mok then
    return err_result(
      name,
      "measurement error (iter " .. (count + 1) .. "): " .. tostring(me),
      clock_src
    )
  end

  local stats = statistics.compute(samples)
  stats.name = name
  stats.timer_source = clock_src
  stats.total_time = total_time
  if jit_samples then
    stats.jitstats = jit_samples
  end
  return stats
end

return M
