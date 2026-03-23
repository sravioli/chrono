--- chrono.jitutil: LuaJIT-specific helpers for timer pre-compilation.

local M = {}

local is_luajit = type(jit) == "table"

--- Try to force-JIT a function and verify it compiled.
-- Uses jit.util.funcbc to check bytecode shifted from FUNCF to JFUNCF.
-- @param fn function    the function to pre-compile
-- @param n  number      iterations to trigger compilation (default 200)
-- @return boolean ok
-- @return string  message
function M.verify_jitted(fn, n)
  if not is_luajit then
    return false, "not running on LuaJIT"
  end

  local ok_util, jit_util = pcall(require, "jit.util")
  if not ok_util or not jit_util or not jit_util.funcbc then
    return false, "jit.util unavailable"
  end

  local ok_bit, bit = pcall(require, "bit")
  if not ok_bit then
    return false, "bit module unavailable"
  end

  n = n or 200
  local start_bc = bit.band(jit_util.funcbc(fn, 0), 0xff)

  for _ = 1, n do
    fn()
  end

  local stop_bc = bit.band(jit_util.funcbc(fn, 0), 0xff)

  if stop_bc == start_bc + 2 then
    return true, "compiled (FUNCF -> JFUNCF)"
  end
  return false, "bytecode did not shift to JFUNCF"
end

return M
