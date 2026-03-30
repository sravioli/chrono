--- chrono.reporters.text: Human-readable plain-text formatter.
-- All formatting logic lives in base.lua. This reporter uses all defaults.

local Base = require "chrono.reporters.base"
local M = Base:extend()

-- Dot-style public API (no `self` needed by external callers).
function M.format_benchmark(r, idx)
  return M:render_one(r, idx)
end

return M
