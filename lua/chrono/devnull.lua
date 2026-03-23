--- chrono.devnull: Cross-platform no-op write sink.
-- Provides file-like :write() and a standalone write() function that
-- discard all output without filesystem overhead.

local M = {}

--- No-op write function.  Accepts any number of arguments, returns true.
-- Mirrors the signature of file:write().
function M.write(...)
  return select("#", ...) >= 0
end

--- File-like object with a :write() method that discards output.
M.file = setmetatable({}, {
  __index = {
    write = function(_, ...)
      return select("#", ...) >= 0
    end,
    flush = function(_)
      return true
    end,
    close = function(_)
      return true
    end,
  },
})

return M
