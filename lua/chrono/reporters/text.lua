--- chrono.reporters.text: Human-readable plain-text formatter.
-- All formatting logic lives in base.lua. This reporter uses all defaults.

local Base = require "chrono.reporters.base"
local M = Base:extend()

-- Expose dot-style public API (no `self` needed by external callers).
function M.start_suite(result)
  return Base.start_suite(M, result)
end
function M.format_benchmark(r, idx)
  return M:render_one(r, idx)
end
function M.finish_suite(result, errs)
  return Base.finish_suite(M, result, errs)
end

return M
