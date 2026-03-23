--- chrono.devnull: Cross-platform no-op write sink.
-- Provides file-like :write() and a standalone write() function that
-- discard all output without filesystem overhead.

local M = {}

--- No-op write function.  Accepts any number of arguments, returns true.
-- Mirrors the signature of file:write().
function M.write(...)
  return true
end

--- File-like object with a :write() method that discards output.
M.file = setmetatable({}, {
  __index = {
    write = function(self, ...)
      return true
    end,
    flush = function(self)
      return true
    end,
    close = function(self)
      return true
    end,
  },
})

return M
