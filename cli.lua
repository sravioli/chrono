#!/usr/bin/env lua
--- chrono.cli: Command-line interface for the benchmarking engine.
---
--- This is a standalone wrapper kept for backward compatibility.
--- The actual CLI logic lives in lua/chrono/cli.lua and is also
--- available as the `chrono` executable installed by LuaRocks.

---------------------------------------------------------------------------
-- Ensure chrono package is loadable from any working directory.
-- cli.lua lives at chrono/cli.lua; the lua/ subdirectory holds the package.
---------------------------------------------------------------------------
do
  local script = arg and arg[0] or "cli.lua"
  local dir = script:match "^(.+)[/\\]" or "."
  package.path = dir .. "/lua/?.lua;" .. dir .. "/lua/?/init.lua;" .. package.path
  package.cpath = dir .. "/c/?.so;" .. dir .. "/c/?.dll;" .. package.cpath
end

require("chrono.cli").main(arg)
