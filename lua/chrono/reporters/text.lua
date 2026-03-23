--- chrono.reporters.text: Human-readable text formatter.

local M = {}

local fmt = string.format

local function ftime(s)
  if s >= 1 then
    return fmt("%8.3f s ", s)
  elseif s >= 1e-3 then
    return fmt("%8.3f ms", s * 1e3)
  elseif s >= 1e-6 then
    return fmt("%8.3f us", s * 1e6)
  else
    return fmt("%8.3f ns", s * 1e9)
  end
end

local function fops(ops)
  if ops ~= ops or ops == math.huge then
    return fmt("%11s", "N/A")
  elseif ops >= 1e9 then
    return fmt("%8.2f  B", ops / 1e9)
  elseif ops >= 1e6 then
    return fmt("%8.2f  M", ops / 1e6)
  elseif ops >= 1e3 then
    return fmt("%8.2f  K", ops / 1e3)
  else
    return fmt("%8.2f   ", ops)
  end
end

local function fcount(n)
  return fmt("%11d", n)
end

local LABEL_W = 7
local GAP = "        "

local function cell(label, value)
  return fmt("%" .. LABEL_W .. "s %s", label, value)
end

local function render_one(r, idx)
  local lines = {}
  local tag = idx and fmt("  [%d] ", idx) or "  "
  local indent = "       "

  if r.error then
    lines[#lines + 1] = tag .. r.name .. "  ** ERROR **"
    lines[#lines + 1] = indent .. r.error
    return table.concat(lines, "\n"), true
  end

  lines[#lines + 1] = tag .. r.name
  lines[#lines + 1] = indent
    .. cell("mean", ftime(r.mean))
    .. GAP
    .. cell("min", ftime(r.min))
    .. GAP
    .. cell("median", ftime(r.median))
  lines[#lines + 1] = indent
    .. cell("stddev", ftime(r.stddev))
    .. GAP
    .. cell("max", ftime(r.max))
    .. GAP
    .. cell("p95", ftime(r.p95))
  lines[#lines + 1] = indent
    .. cell("ops/sec", fops(r.ops_sec))
    .. GAP
    .. cell("samples", fcount(r.n))
    .. GAP
    .. cell("p99", ftime(r.p99))
  lines[#lines + 1] = indent .. cell("total", ftime(r.total_time))
  return table.concat(lines, "\n"), false
end

local function count_errors(benchmarks)
  local errs = 0
  for _, b in ipairs(benchmarks or {}) do
    if b.error then
      errs = errs + 1
    end
  end
  return errs
end

function M.start_suite(result)
  return table.concat({
    "Benchmark Suite: " .. (result.suite_name or "unnamed"),
    fmt(
      "Runtime: %s  |  Timer: %s",
      result.runtime_version or "unknown",
      result.timer_source or "N/A"
    ),
  }, "\n")
end

function M.format_benchmark(result, idx)
  local text = render_one(result, idx)
  return text
end

function M.finish_suite(result)
  return fmt(
    "%d benchmark(s) | %d error(s)",
    #(result.benchmarks or {}),
    count_errors(result.benchmarks)
  )
end

--- Format a suite result or single result as text.
function M.format(result)
  local parts = {}

  if result.benchmarks then
    parts[#parts + 1] = M.start_suite(result)
    parts[#parts + 1] = ""

    for i, b in ipairs(result.benchmarks) do
      parts[#parts + 1] = M.format_benchmark(b, i)
      parts[#parts + 1] = ""
    end
    parts[#parts + 1] = M.finish_suite(result)
  else
    -- Single result
    parts[#parts + 1] = fmt(
      "Runtime: %s  |  Timer: %s",
      result.runtime_version or "unknown",
      result.timer_source or "N/A"
    )
    parts[#parts + 1] = ""
    local text = render_one(result)
    parts[#parts + 1] = text
  end

  return table.concat(parts, "\n")
end

return M
