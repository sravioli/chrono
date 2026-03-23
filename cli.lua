#!/usr/bin/env lua
--- chrono.cli: Command-line interface for the benchmarking engine.

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

local chrono = require "chrono"

---------------------------------------------------------------------------
-- Argument parsing
---------------------------------------------------------------------------

local USAGE = [[
chrono v]] .. chrono._VERSION .. [[

Usage: lua chrono/cli.lua [options]

Options:
  --file <path>        Benchmark file to run (required)
  --format <fmt>       Output format: text, json, pretty   [default: text]
  --timer <src>        Timer source: wall, cpu              [default: wall]
  --iterations <n>     Measurement iterations per benchmark [default: 100]
  --warmup <n>         Warmup iterations per benchmark      [default: 0]
  --min-time <sec>     Minimum measurement time (seconds)   [default: 0]
  --batch-size <n>     Calls per timed iteration            [default: 1]
  --gc-off             Disable GC during measurement
  --gc-collect         Force GC between suite benchmarks
  --randomize          Randomize benchmark execution order
  --out-of-process     Run each benchmark in a child process
  --help               Show this message and exit
]]

local function die(msg)
  io.stderr:write("Error: " .. msg .. "\n\n" .. USAGE)
  os.exit(1)
end

local function parse_args(argv)
  local opts = { format = "text" }
  local i = 1
  while i <= #argv do
    local a = argv[i]
    if a == "--help" or a == "-h" then
      io.write(USAGE)
      os.exit(0)
    elseif a == "--file" then
      i = i + 1
      opts.file = argv[i]
    elseif a == "--format" then
      i = i + 1
      opts.format = argv[i]
    elseif a == "--timer" then
      i = i + 1
      opts.timer_source = argv[i]
    elseif a == "--iterations" then
      i = i + 1
      opts.iterations = tonumber(argv[i])
      if not opts.iterations then
        die "--iterations requires a number"
      end
    elseif a == "--warmup" then
      i = i + 1
      opts.warmup = tonumber(argv[i])
      if not opts.warmup then
        die "--warmup requires a number"
      end
    elseif a == "--min-time" then
      i = i + 1
      opts.min_time = tonumber(argv[i])
      if not opts.min_time then
        die "--min-time requires a number"
      end
    elseif a == "--batch-size" then
      i = i + 1
      opts.batch_size = tonumber(argv[i])
      if not opts.batch_size then
        die "--batch-size requires a number"
      end
    elseif a == "--gc-off" then
      opts.gc_off = true
    elseif a == "--gc-collect" then
      opts.gc_collect = true
    elseif a == "--randomize" then
      opts.randomize = true
    elseif a == "--out-of-process" then
      opts.out_of_process = true
    else
      die("unknown option: " .. a)
    end
    i = i + 1
  end
  return opts
end

---------------------------------------------------------------------------
-- Main
---------------------------------------------------------------------------

local args = parse_args(arg)

if not args.file then
  die "--file is required"
end

-- Load benchmark file (must return a suite object)
local chunk, load_err = loadfile(args.file)
if not chunk then
  die("cannot load benchmark file: " .. tostring(load_err))
end

local ok, suite_or_err = pcall(chunk)
if not ok then
  die("error executing benchmark file: " .. tostring(suite_or_err))
end

local suite = suite_or_err
if type(suite) ~= "table" or not suite.run then
  die(
    "benchmark file must return a suite (got "
      .. type(suite)
      .. "). Use 'return suite' at the end of the file."
  )
end

-- Build run-time overrides from CLI flags
local run_opts = {}
if args.timer_source then
  run_opts.timer_source = args.timer_source
end
if args.iterations then
  run_opts.iterations = args.iterations
end
if args.warmup then
  run_opts.warmup = args.warmup
end
if args.min_time then
  run_opts.min_time = args.min_time
end
if args.batch_size then
  run_opts.batch_size = args.batch_size
end
if args.gc_off then
  run_opts.gc_off = true
end
if args.gc_collect then
  run_opts.gc_collect = true
end
if args.randomize then
  run_opts.randomize = true
end
if args.out_of_process then
  run_opts.out_of_process = true
  run_opts.bench_file = args.file
end

local results = suite:run(run_opts)
chrono.report(results, args.format)
