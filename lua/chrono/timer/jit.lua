---@module "chrono.timer.jit"

local ffi = require "ffi"
local iswin = jit.os == "Windows"

local wall, wall_source
local cpu, cpu_source

if iswin then
  local CDEF = [[
int QueryPerformanceFrequency(int64_t *);
int QueryPerformanceCounter(int64_t *);
typedef void *HANDLE;
typedef struct { unsigned long dwLowDateTime; long dwHighDateTime; } FILETIME;
HANDLE GetCurrentProcess(void);
int GetProcessTimes(HANDLE, FILETIME *, FILETIME *, FILETIME *, FILETIME *);
]]
  if pcall(ffi.cdef, CDEF) then
    local freq_buf, ctr_buf = ffi.new "int64_t[1]", ffi.new "int64_t[1]"
    if ffi.C.QueryPerformanceFrequency(freq_buf) ~= 0 then
      local frequency = tonumber(freq_buf[0])
      wall = function()
        ffi.C.QueryPerformanceCounter(ctr_buf)
        return tonumber(ctr_buf[0]) / frequency
      end
      wall_source = "QueryPerformanceCounter"
    end

    local hProcess = ffi.C.GetCurrentProcess()
    local creation, exit_t, kernel, user =
      ffi.new "FILETIME[1]", ffi.new "FILETIME[1]", ffi.new "FILETIME[1]", ffi.new "FILETIME[1]"

    if pcall(ffi.C.GetProcessTimes, hProcess, creation, exit_t, kernel, user) then
      cpu = function()
        ffi.C.GetProcessTimes(hProcess, creation, exit_t, kernel, user)
        local k = kernel[0].dwLowDateTime + kernel[0].dwHighDateTime * 2 ^ 32
        local u = user[0].dwLowDateTime + user[0].dwHighDateTime * 2 ^ 32
        return (k + u) * 1e-7
      end
      cpu_source = "GetProcessTimes"
    end
  end
else
  local CDEF = [[
typedef struct { long tv_sec; long tv_nsec; } chrono__timespec_t;
int clock_gettime(int, chrono__timespec_t *);
]]
  if pcall(ffi.cdef, CDEF) then
    local ts = ffi.new "chrono__timespec_t"
    local CLOCK_MONOTONIC = ffi.os == "OSX" and 6 or 1

    if pcall(ffi.C.clock_gettime, CLOCK_MONOTONIC, ts) then
      wall = function()
        ffi.C.clock_gettime(CLOCK_MONOTONIC, ts)
        return tonumber(ts.tv_sec) + tonumber(ts.tv_nsec) * 1e-9
      end
      wall_source = "clock_gettime(MONOTONIC)"
    end

    -- POSIX CPU timer: clock_gettime(CLOCK_PROCESS_CPUTIME_ID)
    local CLOCK_PROCESS_CPUTIME_ID = 2
    local cpu_ts = ffi.new "chrono__timespec_t"

    if pcall(ffi.C.clock_gettime, CLOCK_PROCESS_CPUTIME_ID, cpu_ts) then
      cpu = function()
        ffi.C.clock_gettime(CLOCK_PROCESS_CPUTIME_ID, cpu_ts)
        return tonumber(cpu_ts.tv_sec) + tonumber(cpu_ts.tv_nsec) * 1e-9
      end
      cpu_source = "clock_gettime(PROCESS_CPUTIME)"
    end
  end
end

if wall == os.clock then
  local raw_wall = wall
  wall = function()
    return raw_wall()
  end
  jit.off(wall)
end

if cpu == os.clock then
  local raw_cpu = cpu
  cpu = function()
    return raw_cpu()
  end
  jit.off(cpu)
end

---@Chrono.Timer.Jit
return {
  wall = wall,
  wall_source = wall_source,
  cpu = cpu,
  cpu_source = cpu_source,
}
