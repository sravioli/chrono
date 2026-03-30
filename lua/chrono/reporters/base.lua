---@module "chrono.reporters.base"

local M = {}

local fmt = string.format

---------------------------------------------------------------------------
-- Default text formatting helpers (overrideable by derived reporters)
---------------------------------------------------------------------------

--- Format a time value (seconds) as a right-aligned string.
function M:format_time(s)
  local p = self:time_parts(s)
  if not p.value then
    return fmt("%8s", p.special or "N/A") .. " "
  end
  if p.unit == "s" then
    return fmt("%8.3f s ", p.value)
  end
  if p.unit == "ms" then
    return fmt("%8.3f ms", p.value)
  end
  if p.unit == "us" then
    return fmt("%8.3f us", p.value)
  end
  return fmt("%8.3f ns", p.value)
end

--- Format an ops/sec value as a right-aligned string.
function M:format_ops(ops)
  local p = self:ops_parts(ops)
  if not p.value then
    return fmt("%11s", p.special or "N/A")
  end
  if p.suffix == "B" then
    return fmt("%8.3f  B", p.value)
  end
  if p.suffix == "M" then
    return fmt("%8.3f  M", p.value)
  end
  if p.suffix == "K" then
    return fmt("%8.3f  K", p.value)
  end
  return fmt("%8.3f   ", p.value)
end

--- Format a raw count.
function M:format_count(n) -- luacheck: no unused
  return fmt("%11d", n)
end

--- Render a label+value cell (label right-aligned to LABEL_W).
function M:cell(label, value)
  return fmt("%" .. self.LABEL_W .. "s %s", label, value)
end

M.LABEL_W = 7
M.GAP = "        "

function M:time_parts(s) -- luacheck: no unused
  if s ~= s then
    return { value = nil, unit = nil, special = "NaN" }
  end
  if s == math.huge or s == -math.huge then
    return { value = nil, unit = nil, special = (s > 0 and "Infinity" or "-Infinity") }
  end
  if s >= 1 then
    return { value = s, unit = "s" }
  elseif s >= 1e-3 then
    return { value = s * 1e3, unit = "ms" }
  elseif s >= 1e-6 then
    return { value = s * 1e6, unit = "us" }
  else
    return { value = s * 1e9, unit = "ns" }
  end
end

function M:ops_parts(ops) -- luacheck: no unused
  if ops ~= ops then
    return { value = nil, suffix = nil, special = "NaN" }
  end
  if ops == math.huge or ops == -math.huge then
    return { value = nil, suffix = nil, special = (ops > 0 and "Infinity" or "-Infinity") }
  end
  if ops >= 1e9 then
    return { value = ops / 1e9, suffix = "B" }
  elseif ops >= 1e6 then
    return { value = ops / 1e6, suffix = "M" }
  elseif ops >= 1e3 then
    return { value = ops / 1e3, suffix = "K" }
  else
    return { value = ops, suffix = "" }
  end
end

---------------------------------------------------------------------------
-- Declarative stat layout
-- Each row is {  { label, result_key, kind }, ... }
-- kind: "time" | "ops" | "count"
---------------------------------------------------------------------------
M.STAT_ROWS = {
  { { "mean", "mean", "time" }, { "min", "min", "time" }, { "median", "median", "time" } },
  { { "stddev", "stddev", "time" }, { "max", "max", "time" }, { "p95", "p95", "time" } },
  { { "ops/sec", "ops_sec", "ops" }, { "samples", "n", "count" }, { "p99", "p99", "time" } },
}
M.TOTAL_FIELD = { "total", "total_time", "time" }

function M:count_errors(benchmarks) -- luacheck: no unused
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

function M:format_benchmark(result, idx)
  return self:render_one(result, idx)
end

--- Default plain-text render of one benchmark result.
-- Derived reporters override this (or override format_time/format_ops/format_count
-- for styled output without replacing the whole layout).
function M:render_one(r, idx)
  local lines = {}
  local tag = idx and fmt("  [%d] ", idx) or "  "
  local indent = "       "

  if r.error then
    lines[#lines + 1] = tag .. r.name .. "  ** ERROR **"
    lines[#lines + 1] = indent .. r.error
    return table.concat(lines, "\n"), true
  end

  lines[#lines + 1] = tag .. r.name
  if r.tags then
    lines[#lines + 1] = indent .. "tags: " .. table.concat(r.tags, ", ")
  end

  for _, row_def in ipairs(self.STAT_ROWS) do
    local cells = {}
    for _, field in ipairs(row_def) do
      local label, key, kind = field[1], field[2], field[3]
      cells[#cells + 1] = self:cell(label, self["format_" .. kind](self, r[key]))
    end
    lines[#lines + 1] = indent .. table.concat(cells, self.GAP)
  end

  local tf = self.TOTAL_FIELD
  lines[#lines + 1] = indent .. self:cell(tf[1], self["format_" .. tf[3]](self, r[tf[2]]))
  return table.concat(lines, "\n"), false
end

--- Default suite footer.
function M.finish_suite(result, override_errs)
  local errs = override_errs or M:count_errors(result.benchmarks)
  return fmt("%d benchmark(s) | %d error(s)", #(result.benchmarks or {}), errs)
end

--- Orchestrate full suite or single-benchmark output.
-- start_suite / finish_suite are dot functions: first arg is result, not self.
-- Lookup goes through self for polymorphism, but calls are dot-style.
function M:_do_format(result)
  local parts = {}
  local render_errs = 0

  if result.benchmarks then
    parts[#parts + 1] = self.start_suite(result)
    parts[#parts + 1] = ""

    for i, b in ipairs(result.benchmarks) do
      local ok, s, is_err = pcall(self.render_one, self, b, i)
      if not ok then
        render_errs = render_errs + 1
        parts[#parts + 1] = "(reporter error: " .. tostring(s) .. ")"
      else
        parts[#parts + 1] = s
        if is_err then
          render_errs = render_errs + 1
        end
      end
      parts[#parts + 1] = ""
    end

    local total_errs = self:count_errors(result.benchmarks) + render_errs
    parts[#parts + 1] = self.finish_suite(result, total_errs)
  else
    parts[#parts + 1] = self.start_suite(result)
    parts[#parts + 1] = ""
    local ok, s, is_err = pcall(self.render_one, self, result)
    if not ok then
      parts[#parts + 1] = "(reporter error: " .. tostring(s) .. ")"
    else
      parts[#parts + 1] = s
    end
    local _ = is_err -- unused for single results
  end

  return table.concat(parts, "\n")
end

--- Create a derived reporter inheriting all methods from this base.
-- The derived table gets:
--   • metatable __index pointing to the base
--   • format(result) wired to call _do_format with the derived table as self
-- Only override what differs: render_one, start_suite, finish_suite,
-- format_time, format_ops, format_count.
function M:extend(t)
  t = t or {}
  setmetatable(t, { __index = self })
  local derived = t
  t.format = function(result)
    return derived:_do_format(result)
  end
  return t
end

return M
