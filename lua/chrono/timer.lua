--- chrono.timer: High-resolution timer abstraction.
-- Selects the best available clock source per runtime.

local M = {}

M.is_luajit = type(jit) == "table"
M.runtime = M.is_luajit and "LuaJIT" or "Lua"
M.runtime_version = M.is_luajit and jit.version or _VERSION

local wall_fn, wall_source
local cpu_fn, cpu_source

---------------------------------------------------------------------------
-- 1. Try optional native C module (skip on LuaJIT — FFI is preferred and
--    the C module may be compiled against an incompatible Lua ABI)
---------------------------------------------------------------------------
if not M.is_luajit then
  local clock_ok, clock_mod = pcall(require, "chrono.clock")
  if clock_ok and type(clock_mod) == "table" then
    wall_fn = clock_mod.wall
    wall_source = clock_mod.wall_source()
    cpu_fn = clock_mod.cpu
    cpu_source = clock_mod.cpu_source()
  end
end

---------------------------------------------------------------------------
-- 2. Try LuaJIT FFI (if C module was not available)
---------------------------------------------------------------------------
if not wall_fn and M.is_luajit then
  local ffi_ok, ffi = pcall(require, "ffi")
  if ffi_ok then
    if ffi.os == "Windows" then
      local def_ok = pcall(
        ffi.cdef,
        [[
                int QueryPerformanceFrequency(int64_t *);
                int QueryPerformanceCounter(int64_t *);
                typedef void *HANDLE;
                typedef struct { unsigned long dwLowDateTime; long dwHighDateTime; } FILETIME;
                HANDLE GetCurrentProcess(void);
                int GetProcessTimes(HANDLE, FILETIME *, FILETIME *, FILETIME *, FILETIME *);
            ]]
      )
      if def_ok then
        local freq_buf = ffi.new "int64_t[1]"
        local ctr_buf = ffi.new "int64_t[1]"
        if ffi.C.QueryPerformanceFrequency(freq_buf) ~= 0 then
          local frequency = tonumber(freq_buf[0])
          wall_fn = function()
            ffi.C.QueryPerformanceCounter(ctr_buf)
            return tonumber(ctr_buf[0]) / frequency
          end
          wall_source = "QueryPerformanceCounter"
        end

        local hProcess = ffi.C.GetCurrentProcess()
        local creation = ffi.new "FILETIME[1]"
        local exit_t = ffi.new "FILETIME[1]"
        local kernel = ffi.new "FILETIME[1]"
        local user = ffi.new "FILETIME[1]"
        local probe_ok =
          pcall(ffi.C.GetProcessTimes, hProcess, creation, exit_t, kernel, user)
        if probe_ok then
          cpu_fn = function()
            ffi.C.GetProcessTimes(hProcess, creation, exit_t, kernel, user)
            local k = kernel[0].dwLowDateTime + kernel[0].dwHighDateTime * 2 ^ 32
            local u = user[0].dwLowDateTime + user[0].dwHighDateTime * 2 ^ 32
            return (k + u) * 1e-7
          end
          cpu_source = "GetProcessTimes"
        end
      end
    else
      -- POSIX: clock_gettime(CLOCK_MONOTONIC)
      local def_ok = pcall(
        ffi.cdef,
        [[
                typedef struct { long tv_sec; long tv_nsec; } chrono__timespec_t;
                int clock_gettime(int, chrono__timespec_t *);
            ]]
      )
      if def_ok then
        local ts = ffi.new "chrono__timespec_t"
        local CLOCK_MONOTONIC = ffi.os == "OSX" and 6 or 1
        local probe_ok = pcall(ffi.C.clock_gettime, CLOCK_MONOTONIC, ts)
        if probe_ok then
          wall_fn = function()
            ffi.C.clock_gettime(CLOCK_MONOTONIC, ts)
            return tonumber(ts.tv_sec) + tonumber(ts.tv_nsec) * 1e-9
          end
          wall_source = "clock_gettime(MONOTONIC)"
        end

        -- POSIX CPU timer: clock_gettime(CLOCK_PROCESS_CPUTIME_ID)
        local CLOCK_PROCESS_CPUTIME_ID = 2
        local cpu_ts = ffi.new "chrono__timespec_t"
        local cpu_probe_ok = pcall(ffi.C.clock_gettime, CLOCK_PROCESS_CPUTIME_ID, cpu_ts)
        if cpu_probe_ok then
          cpu_fn = function()
            ffi.C.clock_gettime(CLOCK_PROCESS_CPUTIME_ID, cpu_ts)
            return tonumber(cpu_ts.tv_sec) + tonumber(cpu_ts.tv_nsec) * 1e-9
          end
          cpu_source = "clock_gettime(PROCESS_CPUTIME)"
        end
      end
    end
  end
end

-- 3. Fallbacks
if not wall_fn then
  wall_fn = os.clock
  wall_source = "os.clock (CPU-time fallback)"
end

if not cpu_fn then
  cpu_fn = os.clock
  cpu_source = "os.clock"
end

---------------------------------------------------------------------------
-- 4. JIT isolation — prevent LuaJIT from trying to trace un-JIT-able
--    os.clock wrappers, which causes trace aborts and unpredictable overhead.
---------------------------------------------------------------------------
if M.is_luajit and jit then
  if wall_fn == os.clock then
    local raw_wall = wall_fn
    wall_fn = function()
      return raw_wall()
    end
    jit.off(wall_fn)
  end
  if cpu_fn == os.clock then
    local raw_cpu = cpu_fn
    cpu_fn = function()
      return raw_cpu()
    end
    jit.off(cpu_fn)
  end
end

M.wall = wall_fn
M.wall_source = wall_source
M.cpu = cpu_fn
M.cpu_source = cpu_source

--- Resolve a timer function by source name.
-- @param source string "wall"|"cpu" (default "wall")
-- @return function clock, string source_name
function M.resolve(source)
  source = source or "wall"
  if source == "wall" then
    return M.wall, M.wall_source
  elseif source == "cpu" then
    return M.cpu, M.cpu_source
  end
  error("chrono.timer: unknown source '" .. tostring(source) .. "'")
end

return M
