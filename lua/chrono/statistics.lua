--- chrono.statistics: Metric computations for benchmark samples.

local M = {}

local sqrt = math.sqrt
local ceil = math.ceil
local huge = math.huge
local sort = table.sort

--- Compute descriptive statistics from an array of durations (seconds).
-- @param samples number[]
-- @return table
function M.compute(samples)
  local n = #samples
  if n == 0 then
    return { n = 0, error = "no samples collected" }
  end

  local sum = 0
  local lo = samples[1]
  local hi = samples[1]

  for i = 1, n do
    local v = samples[i]
    sum = sum + v
    if v < lo then
      lo = v
    end
    if v > hi then
      hi = v
    end
  end

  local mean = sum / n

  -- Sample standard deviation (Bessel-corrected)
  local ss = 0
  for i = 1, n do
    local d = samples[i] - mean
    ss = ss + d * d
  end
  local stddev = n > 1 and sqrt(ss / (n - 1)) or 0

  -- Sorted copy for order statistics
  local sorted = {}
  for i = 1, n do
    sorted[i] = samples[i]
  end
  sort(sorted)

  local function pct(p)
    if n == 1 then
      return sorted[1]
    end
    local r = ceil(p / 100 * n)
    if r < 1 then
      r = 1
    end
    if r > n then
      r = n
    end
    return sorted[r]
  end

  return {
    n = n,
    min = lo,
    max = hi,
    mean = mean,
    stddev = stddev,
    median = pct(50),
    p95 = pct(95),
    p99 = pct(99),
    ops_sec = mean > 0 and (1 / mean) or huge,
  }
end

return M
