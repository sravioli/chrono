--- chrono.reporters.base: Shared base reporter functionality.
--- chrono.reporters.base: Base reporter with shared formatting logic.

local Base = {}

local fmt = string.format

function Base:count_errors(benchmarks)
  local errs = 0
  for _, b in ipairs(benchmarks or {}) do
    if b.error then
      errs = errs + 1
    end
  end
  return errs
end

function Base:start_suite(result)
  return table.concat({
    "Benchmark Suite: " .. (result.suite_name or "unnamed"),
    fmt(
      "Runtime: %s  |  Timer: %s",
      result.runtime_version or "unknown",
      result.timer_source or "N/A"
    ),
  }, "\n")
end

function Base:format_benchmark(result, idx)
  if type(self.render_one) == "function" then
    return self:render_one(result, idx)
  end
  if result.error then
    return ((idx and string.format("  [%d] ", idx) or "  ") .. result.name .. "  ** ERROR **\n       " .. (result.error or "")), true
  end
  return (idx and string.format("  [%d] ", idx) or "  ") .. result.name, false
end

function Base:finish_suite(result)
  return fmt(
    "%d benchmark(s) | %d error(s)",
    #(result.benchmarks or {}),
    self:count_errors(result.benchmarks)
  )
end

function Base:format(result)
  local parts = {}

  if result.benchmarks then
    parts[#parts + 1] = self:start_suite(result)
    parts[#parts + 1] = ""

    for i, b in ipairs(result.benchmarks) do
      parts[#parts + 1] = self:format_benchmark(b, i)
      parts[#parts + 1] = ""
    end
    parts[#parts + 1] = self:finish_suite(result)
  else
    parts[#parts + 1] = fmt(
      "Runtime: %s  |  Timer: %s",
      result.runtime_version or "unknown",
      result.timer_source or "N/A"
    )
    parts[#parts + 1] = ""
    parts[#parts + 1] = self:format_benchmark(result)
  end

  return table.concat(parts, "\n")
end

return Base
