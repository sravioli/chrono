--- chrono.reporters.pretty: ANSI-colored UTF-8 terminal formatter.

local Base = require "chrono.reporters.base"
local M = Base:extend()

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
-- Raw value extractors (plain-text number + unit, no ANSI)
---------------------------------------------------------------------------

function M:raw_time(s)
  local p = self:time_parts(s)
  if not p.value then
    return (p.special or "N/A"), ""
  end
  return fmt("%.3f", p.value), (p.unit == "us" and "µs" or p.unit)
end

function M:raw_ops(ops)
  local p = self:ops_parts(ops)
  if not p.value then
    return (p.special or "N/A"), ""
  end
  return fmt("%.3f", p.value), p.suffix
end

function M:raw_count(n)
  return tostring(n), ""
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

local function boxline(content, inner_w)
  return fmt(" %s %s %s", V, pad(content, inner_w), V)
end

local function max_vislen(items)
  local w = 0
  for _, s in ipairs(items) do
    local n = vislen(s)
    if n > w then
      w = n
    end
  end
  return w
end

local function render_one(self, r, idx)
  local lines = {}
  local tag = idx and fmt("#%d", idx) or ""

  if r.error then
    local title = bold
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
    local err_line = red .. r.error .. reset
    local inner_w = max_vislen { title, err_line }

    lines[#lines + 1] = " " .. hline(TOP_L, TOP_R, inner_w + 2)
    lines[#lines + 1] = boxline(title, inner_w)
    lines[#lines + 1] = " " .. hline(SEP_L, SEP_R, inner_w + 2)
    lines[#lines + 1] = boxline(err_line, inner_w)
    lines[#lines + 1] = " " .. hline(BOT_L, BOT_R, inner_w + 2)
    return table.concat(lines, "\n"), true
  end

  local header_line = bold
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
  local tags_line = nil
  if r.tags then
    tags_line = dim .. "tags: " .. table.concat(r.tags, ", ") .. reset
  end

  -- Build raw value grid: grid[row][col] = {label, number_str, unit_str}
  local grid = {}
  for row_i, row_def in ipairs(self.STAT_ROWS) do
    grid[row_i] = {}
    for col_i, field in ipairs(row_def) do
      local label, key, kind = field[1], field[2], field[3]
      local num, unit = self["raw_" .. kind](self, r[key])
      grid[row_i][col_i] = { label, num, unit }
    end
  end

  -- Compute per-column max widths
  local ncols = #self.STAT_ROWS[1]
  local lw, nw, uw = {}, {}, {}
  for c = 1, ncols do
    lw[c], nw[c], uw[c] = 0, 0, 0
    for row = 1, #grid do
      local g = grid[row][c]
      lw[c] = math.max(lw[c], #g[1])
      nw[c] = math.max(nw[c], #g[2])
      uw[c] = math.max(uw[c], vislen(g[3]))
    end
  end

  -- Format stat rows with aligned columns
  local stat_lines = {}
  for row_i = 1, #grid do
    local parts = {}
    for col_i = 1, ncols do
      local g = grid[row_i][col_i]
      local lbl = cyan .. fmt("%" .. lw[col_i] .. "s", g[1]) .. reset
      local num = bold .. white .. fmt("%" .. nw[col_i] .. "s", g[2]) .. reset
      local unit = ""
      if uw[col_i] > 0 then
        unit = " " .. dim .. pad(g[3], uw[col_i]) .. reset
      end
      parts[#parts + 1] = lbl .. " " .. num .. unit
    end
    stat_lines[#stat_lines + 1] = table.concat(parts, "  ")
  end

  -- Total (separated)
  local tf = self.TOTAL_FIELD
  local t_num, t_unit = self["raw_" .. tf[3]](self, r[tf[2]])
  local total_line = blue .. tf[1] .. reset .. " " .. bold .. white .. t_num .. reset
  if t_unit ~= "" then
    total_line = total_line .. " " .. dim .. t_unit .. reset
  end

  local width_inputs = { header_line, total_line }
  if tags_line then
    width_inputs[#width_inputs + 1] = tags_line
  end
  for _, s in ipairs(stat_lines) do
    width_inputs[#width_inputs + 1] = s
  end
  local inner_w = max_vislen(width_inputs)

  lines[#lines + 1] = " " .. hline(TOP_L, TOP_R, inner_w + 2)
  lines[#lines + 1] = boxline(header_line, inner_w)
  if tags_line then
    lines[#lines + 1] = boxline(tags_line, inner_w)
  end
  lines[#lines + 1] = " " .. hline(SEP_L, SEP_R, inner_w + 2)
  for _, s in ipairs(stat_lines) do
    lines[#lines + 1] = boxline(s, inner_w)
  end
  lines[#lines + 1] = " " .. hline(SEP_L, SEP_R, inner_w + 2)
  lines[#lines + 1] = boxline(total_line, inner_w)

  -- Bottom
  lines[#lines + 1] = " " .. hline(BOT_L, BOT_R, inner_w + 2)

  return table.concat(lines, "\n"), false
end

---------------------------------------------------------------------------
-- Colon-method overrides (used by Base:format via inheritance)
---------------------------------------------------------------------------

function M:render_one(r, idx)
  return render_one(self, r, idx)
end

local function suite_header(result)
  result = result or {}
  local parts = {
    bold .. magenta .. "  ◆ " .. reset .. bold .. (result.suite_name or "unnamed") .. reset,
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

local function suite_footer(benchmarks, override_errs)
  benchmarks = benchmarks or {}
  local errs = override_errs or 0
  if errs > 0 then
    return "  "
      .. green
      .. fmt("%d", #benchmarks - errs)
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
    .. fmt("%d benchmark(s)", #benchmarks)
    .. reset
    .. " "
    .. green
    .. "all ok"
    .. reset
end

-- Base:format calls these as self.start_suite(result) / self.finish_suite(result, errs)
-- so they are dot-style functions: first arg is the result table, not self.
function M.start_suite(result)
  return suite_header(result)
end

function M.finish_suite(result, override_errs)
  result = result or {}
  local errs = override_errs or Base.count_errors(result.benchmarks)
  return suite_footer(result.benchmarks, errs)
end

---------------------------------------------------------------------------
-- Dot-style public API (for external callers / tests without self)
---------------------------------------------------------------------------

function M.format_benchmark(r, idx)
  return M:render_one(r, idx)
end

return M
