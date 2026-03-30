--- chrono.reporters.csv: Comma-separated output for spreadsheets and CI pipelines.

local Base = require "chrono.reporters.base"
local M = Base:extend()

local fmt = string.format
local concat = table.concat

local COLUMNS = {
  "suite_name",
  "benchmark_index",
  "name",
  "status",
  "error",
  "tags",
  "mean",
  "mean_unit",
  "min",
  "min_unit",
  "median",
  "median_unit",
  "stddev",
  "stddev_unit",
  "max",
  "max_unit",
  "p95",
  "p95_unit",
  "p99",
  "p99_unit",
  "ops_sec",
  "ops_suffix",
  "samples",
  "total_time",
  "total_time_unit",
  "runtime_version",
  "timer_source",
}

local function csv_escape(v)
  if v == nil then
    return ""
  end
  local s = tostring(v)
  if s:find '[",\n\r]' then
    return '"' .. s:gsub('"', '""') .. '"'
  end
  return s
end

local function stringify_time(self, value)
  local p = self:time_parts(value or 0)
  if not p.value then
    return p.special or "N/A", ""
  end
  return fmt("%.3f", p.value), p.unit
end

local function stringify_ops(self, value)
  local p = self:ops_parts(value or 0)
  if not p.value then
    return p.special or "N/A", ""
  end
  return fmt("%.3f", p.value), p.suffix
end

local function row_for(self, suite, result, idx)
  local mean, mean_unit = stringify_time(self, result.mean)
  local minv, min_unit = stringify_time(self, result.min)
  local median, median_unit = stringify_time(self, result.median)
  local stddev, stddev_unit = stringify_time(self, result.stddev)
  local maxv, max_unit = stringify_time(self, result.max)
  local p95, p95_unit = stringify_time(self, result.p95)
  local p99, p99_unit = stringify_time(self, result.p99)
  local ops, ops_suffix = stringify_ops(self, result.ops_sec)
  local total, total_unit = stringify_time(self, result.total_time)

  local status = result.error and "error" or "ok"
  local tags = ""
  if result.tags and #result.tags > 0 then
    tags = concat(result.tags, "|")
  end

  local values = {
    suite and suite.suite_name or "",
    idx or "",
    result.name or "",
    status,
    result.error or "",
    tags,
    mean,
    mean_unit,
    minv,
    min_unit,
    median,
    median_unit,
    stddev,
    stddev_unit,
    maxv,
    max_unit,
    p95,
    p95_unit,
    p99,
    p99_unit,
    ops,
    ops_suffix,
    result.n or "",
    total,
    total_unit,
    suite and suite.runtime_version or result.runtime_version or "",
    suite and suite.timer_source or result.timer_source or "",
  }

  for i = 1, #values do
    values[i] = csv_escape(values[i])
  end
  return concat(values, ",")
end

--- Format suite or single-benchmark results as CSV.
function M.format(result)
  local lines = { concat(COLUMNS, ",") }

  if result and result.benchmarks then
    for i, bench in ipairs(result.benchmarks) do
      lines[#lines + 1] = row_for(M, result, bench, i)
    end
  elseif result then
    lines[#lines + 1] = row_for(M, nil, result, nil)
  end

  return concat(lines, "\n")
end

return M
