---@module "chrono.timer"

---@class Chrono.Timer
local M = {}

M.isjit = type(jit) == "table"
M.runtime = M.isjit and "LuaJIT" or "Lua"
M.runtime_version = M.isjit and jit.version or _VERSION

local wall, wall_source
local cpu, cpu_source

-- try load C module
if not M.isjit then
  local std = require "chrono.timer.std"
  wall, wall_source = std.wall, std.wall_source
  cpu, cpu_source = std.cpu, std.cpu_source
else
  local luajit = require "chrono.timer.luajit"
  wall, wall_source = luajit.wall, luajit.wall_source
  cpu, cpu_source = luajit.cpu, luajit.cpu_source
end

M.get = function(source)
  source = source or "wall"
  if source == "wall" then
    return wall, wall_source
  elseif source == "cpu" then
    return cpu, cpu_source
  end
  error("chrono.timer: unknown source '" .. tostring(source) .. "'")
end

return M
