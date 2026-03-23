package.path = "lua/?.lua;lua/?/init.lua;" .. package.path
package.cpath = "c/?.dll;c/?.so;" .. package.cpath
local t = require "chrono.timer"
print("wall: " .. t.wall_source)
print("cpu:  " .. t.cpu_source)
