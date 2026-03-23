--- chrono.reporters.pretty: ANSI-colored UTF-8 terminal formatter.

local M = {}

local fmt = string.format

---------------------------------------------------------------------------
-- ANSI helpers
---------------------------------------------------------------------------

local ESC = "\27["

local function sgr(code)
  return ESC .. code .. "m"
end

local reset = sgr(0)
local bold = sgr(1)
local dim = sgr(2)
local red = sgr(31)
local green = sgr(32)
local yellow = sgr(33)
local blue = sgr(34)
local magenta = sgr(35)
local cyan = sgr(36)
local white = sgr(37)

---------------------------------------------------------------------------
-- Value formatting (with color)
---------------------------------------------------------------------------

local function ftime(s)
  local val, unit
  if s >= 1 then
    val, unit = fmt("%.3f", s), "s "
  elseif s >= 1e-3 then
    val, unit = fmt("%.3f", s * 1e3), "ms"
  elseif s >= 1e-6 then
    val, unit = fmt("%.3f", s * 1e6), "µs"
  else
    val, unit = fmt("%.3f", s * 1e9), "ns"
  end
  return bold .. white .. fmt("%8s", val) .. reset .. " " .. dim .. unit .. reset
end

local function fops(ops)
  if ops ~= ops or ops == math.huge then
    return bold .. white .. fmt("%8s", "N/A") .. reset .. " " .. dim .. "  " .. reset
  end
  local val, suffix
  if ops >= 1e9 then
    val, suffix = fmt("%.2f", ops / 1e9), "B "
  elseif ops >= 1e6 then
    val, suffix = fmt("%.2f", ops / 1e6), "M "
  elseif ops >= 1e3 then
    val, suffix = fmt("%.2f", ops / 1e3), "K "
  else
    val, suffix = fmt("%.2f", ops), "  "
  end
  return bold .. white .. fmt("%8s", val) .. reset .. " " .. dim .. suffix .. reset
end

local function fcount(n)
  return bold .. white .. fmt("%11d", n) .. reset
end

---------------------------------------------------------------------------
-- Box-drawing pieces
---------------------------------------------------------------------------

local TOP_L = "╭"
local TOP_R = "╮"
local BOT_L = "╰"
local BOT_R = "╯"
local H = "─"
local V = "│"
local SEP_L = "├"
local SEP_R = "┤"

local function hline(left, right, width)
  return left .. string.rep(H, width) .. right
end

---------------------------------------------------------------------------
-- Render a single benchmark result
---------------------------------------------------------------------------

local INNER_W = 68 -- content width inside the box

-- Count visible columns (UTF-8 codepoints, ignoring ANSI escapes).
local function vislen(s)
  local plain = s:gsub("\27%[[%d;]*m", "")
  local n = 0
  for i = 1, #plain do
    local b = plain:byte(i)
    -- Count only lead bytes (ASCII 0x00-0x7F or multi-byte start 0xC0+)
    if b < 0x80 or b >= 0xC0 then
      n = n + 1
    end
  end
  return n
end

local function pad(s, w)
  local vis = vislen(s)
  if vis < w then
    return s .. string.rep(" ", w - vis)
  end
  return s
end

local function boxline(content)
  return fmt(" %s %s %s", V, pad(content, INNER_W), V)
end

local function render_one(r, idx)
  local lines = {}
  local tag = idx and fmt("#%d", idx) or ""

  if r.error then
    lines[#lines + 1] = " " .. hline(TOP_L, TOP_R, INNER_W + 2)
    lines[#lines + 1] = boxline(
      bold
        .. red
        .. "✗ "
        .. reset
        .. yellow
        .. tag
        .. reset
        .. " "
        .. bold
        .. r.name
        .. reset
    )
    lines[#lines + 1] = " " .. hline(SEP_L, SEP_R, INNER_W + 2)
    lines[#lines + 1] = boxline(red .. r.error .. reset)
    lines[#lines + 1] = " " .. hline(BOT_L, BOT_R, INNER_W + 2)
    return table.concat(lines, "\n"), true
  end

  -- Header
  lines[#lines + 1] = " " .. hline(TOP_L, TOP_R, INNER_W + 2)
  lines[#lines + 1] = boxline(
    bold
      .. green
      .. "● "
      .. reset
      .. yellow
      .. tag
      .. reset
      .. " "
      .. bold
      .. r.name
      .. reset
  )
  lines[#lines + 1] = " " .. hline(SEP_L, SEP_R, INNER_W + 2)

  -- Stats rows: label (colored) + value
  local function row(label, value)
    local colored_label = cyan .. fmt("%-8s", label) .. reset
    return colored_label .. " " .. value
  end

  -- Row 1: mean / min / median
  lines[#lines + 1] = boxline(
    row("mean", ftime(r.mean))
      .. "    "
      .. row("min", ftime(r.min))
      .. "    "
      .. row("median", ftime(r.median))
  )

  -- Row 2: stddev / max / p95
  lines[#lines + 1] = boxline(
    row("stddev", ftime(r.stddev))
      .. "    "
      .. row("max", ftime(r.max))
      .. "    "
      .. row("p95", ftime(r.p95))
  )

  -- Row 3: ops/sec / samples / p99
  lines[#lines + 1] = boxline(
    row("ops/sec", fops(r.ops_sec))
      .. "    "
      .. row("samples", fcount(r.n))
      .. "    "
      .. row("p99", ftime(r.p99))
  )

  -- Row 4: total
  lines[#lines + 1] = " " .. hline(SEP_L, SEP_R, INNER_W + 2)
  lines[#lines + 1] = boxline(blue .. "total " .. reset .. ftime(r.total_time))

  -- Bottom
  lines[#lines + 1] = " " .. hline(BOT_L, BOT_R, INNER_W + 2)

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
  local parts = {
    bold
      .. magenta
      .. "  ◆ "
      .. reset
      .. bold
      .. (result.suite_name or "unnamed")
      .. reset,
    blue
      .. fmt("    runtime %s  ", result.runtime_version or "unknown")
      .. reset
      .. "│"
      .. blue
      .. fmt("  timer %s", result.timer_source or "N/A")
      .. reset,
  }
  return table.concat(parts, "\n")
end

function M.format_benchmark(result, idx)
  local text = render_one(result, idx)
  return text
end

function M.finish_suite(result)
  local errs = count_errors(result.benchmarks)
  if errs > 0 then
    return "  "
      .. green
      .. fmt("%d", #(result.benchmarks or {}) - errs)
      .. " passed"
      .. reset
      .. "  "
      .. red
      .. fmt("%d", errs)
      .. " failed"
      .. reset
  end
  return "  "
    .. green
    .. fmt("%d benchmark(s)", #(result.benchmarks or {}))
    .. reset
    .. " "
    .. green
    .. "all ok"
    .. reset
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Format a suite result or single result as colored UTF-8 text.
function M.format(result)
  local parts = {}

  if result.benchmarks then
    parts[#parts + 1] = ""
    parts[#parts + 1] = M.start_suite(result)
    parts[#parts + 1] = ""

    for i, b in ipairs(result.benchmarks) do
      parts[#parts + 1] = M.format_benchmark(b, i)
      parts[#parts + 1] = ""
    end
    parts[#parts + 1] = M.finish_suite(result)
    parts[#parts + 1] = ""
  else
    -- Single result
    parts[#parts + 1] = ""
    parts[#parts + 1] = blue
      .. fmt("  runtime %s  ", result.runtime_version or "unknown")
      .. reset
      .. "│"
      .. blue
      .. fmt("  timer %s", result.timer_source or "N/A")
      .. reset
    parts[#parts + 1] = ""
    local text = render_one(result)
    parts[#parts + 1] = text
    parts[#parts + 1] = ""
  end

  return table.concat(parts, "\n")
end

return M
