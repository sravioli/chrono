---@module "chrono.timer.std"

local wall, wall_source
local cpu, cpu_source

local clock_ok, clock_mod = pcall(require, "chrono.clock")
if clock_ok and type(clock_mod) == "table" then
  wall, wall_source = clock_mod.wall, clock_mod.wall_source()
  cpu, cpu_source = clock_mod.cpu, clock_mod.cpu_source()
end

if not wall then
  wall, wall_source = os.clock, "os.clock (CPU-time fallback)"
end

if not cpu then
  cpu, cpu_source = os.clock, "os.clock"
end

---@class Chrono.Timer.Standard
return {
  wall = wall,
  wall_source = wall_source,
  cpu = cpu,
  cpu_source = cpu_source,
}
