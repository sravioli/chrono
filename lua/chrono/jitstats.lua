--- chrono.jitstats: Optional LuaJIT trace statistics collector.
-- Captures per-iteration JIT compilation events (trace starts, aborts, etc.)
-- using jit.attach.  Safe to require on non-LuaJIT runtimes (becomes a no-op).

local M = {}

local is_luajit = type(jit) == "table"

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local active = false
local current_stats = nil

local function make_stats()
  return { starts = 0, aborts = 0, flushes = 0 }
end

---------------------------------------------------------------------------
-- jit.attach callbacks
---------------------------------------------------------------------------

local function on_trace(what)
  if not current_stats then
    return
  end
  if what == "start" then
    current_stats.starts = current_stats.starts + 1
  elseif what == "abort" then
    current_stats.aborts = current_stats.aborts + 1
  elseif what == "flush" then
    current_stats.flushes = current_stats.flushes + 1
  end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Is the jitstats collector available (LuaJIT with jit.attach)?
M.available = false

if is_luajit then
  local ok = pcall(function()
    -- Probe: attach and immediately detach to verify jit.attach works.
    jit.attach(on_trace, "trace")
    jit.attach(on_trace) -- detach
  end)
  M.available = ok
end

--- Start collecting trace statistics.
-- @return boolean  true if collection started, false if unavailable.
function M.start()
  if not M.available then
    return false
  end
  if active then
    return true
  end
  current_stats = make_stats()
  jit.attach(on_trace, "trace")
  active = true
  return true
end

--- Stop collecting trace statistics.
function M.stop()
  if not active then
    return
  end
  pcall(jit.attach, on_trace) -- detach
  active = false
end

--- Reset counters to zero.
function M.reset()
  current_stats = make_stats()
end

--- Return a snapshot of the current counters.
-- @return table  { starts, aborts, flushes }
function M.snapshot()
  if not current_stats then
    return make_stats()
  end
  return {
    starts = current_stats.starts,
    aborts = current_stats.aborts,
    flushes = current_stats.flushes,
  }
end

--- Compute the difference between two snapshots.
-- @param before table
-- @param after  table
-- @return table
function M.diff(before, after)
  return {
    starts = after.starts - before.starts,
    aborts = after.aborts - before.aborts,
    flushes = after.flushes - before.flushes,
  }
end

--- Wrap a runner so each iteration captures JIT stats.
-- Returns a function that takes (clock, fn, batch) and returns
-- (elapsed_time, iter_jitstats).
-- @return function|nil  nil if unavailable
function M.make_instrumented_timer()
  if not M.available then
    return nil
  end

  return function(clock, fn, batch)
    local before = M.snapshot()
    local t0 = clock()
    if batch > 1 then
      for _ = 1, batch do
        fn()
      end
    else
      fn()
    end
    local t1 = clock()
    local after = M.snapshot()
    return t1 - t0, M.diff(before, after)
  end
end

return M
