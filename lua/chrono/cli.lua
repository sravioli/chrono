--- chrono.cli: Command-line interface for the benchmarking engine.
--
-- Loads a `.chrono` config file (Lua table, like `.busted`), discovers
-- benchmark files in a root directory, and runs them.

local chrono = require "chrono"

local M = {}

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
  ROOT = { "bench/" },
  pattern = "_bench",
  format = "text",
  timer_source = nil,
  iterations = nil,
  warmup = nil,
  min_time = nil,
  batch_size = nil,
  gc_off = false,
  gc_collect = false,
  randomize = false,
  out_of_process = false,
}

---------------------------------------------------------------------------
-- Usage
---------------------------------------------------------------------------

local USAGE = [[
chrono v]] .. chrono._VERSION .. [[

Usage: chrono [options] [file ...]

Options:
  --lua <interp>       Re-run under a different interpreter (e.g. luajit)
  --file <path>        Benchmark file to run (may be repeated)
  --root <dir>         Root directories for auto-discovery (may be repeated)
  --pattern <pat>      Lua pattern for benchmark filenames  [default: _bench]
  --format <fmt>       Output format: text, json, pretty    [default: text]
  --timer <src>        Timer source: wall, cpu               [default: wall]
  --iterations <n>     Measurement iterations per benchmark  [default: 100]
  --warmup <n>         Warmup iterations per benchmark       [default: 0]
  --min-time <sec>     Minimum measurement time (seconds)    [default: 0]
  --batch-size <n>     Calls per timed iteration             [default: 1]
  --gc-off             Disable GC during measurement
  --gc-collect         Force GC between suite benchmarks
  --randomize          Randomize benchmark execution order
  --out-of-process     Run each benchmark in a child process
  --help               Show this message and exit

Config:
  If a .chrono file exists in the working directory it is loaded as a Lua
  table (like busted's .busted).  CLI flags override config values.  The
  config may define named profiles; the "default" profile is used.

Auto-discovery:
  When no --file is given, chrono searches ROOT directories (default: bench/)
  for files whose names match PATTERN (default: _bench).
]]

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function die(msg)
  io.stderr:write("Error: " .. msg .. "\n\n" .. USAGE)
  os.exit(1)
end

local IS_WINDOWS = package.config:sub(1, 1) == "\\"
local SEP = IS_WINDOWS and "\\" or "/"

--- Check whether `path` is a directory.
local function isdir(path)
  local d = path:gsub("[/\\]$", "")
  if IS_WINDOWS then
    local pipe = io.popen('if exist "' .. d .. '\\*" (echo Y) else (echo N)', "r")
    if pipe then
      local out = pipe:read "*l"
      pipe:close()
      return out == "Y"
    end
    return false
  else
    -- test -d is POSIX
    return os.execute('test -d "' .. d .. '"') == 0
  end
end

--- Recursively find files matching `pattern` under `dir`.
local function find_files(dir, pattern)
  local found = {}
  local d = dir:gsub("[/\\]$", "")
  local cmd
  if IS_WINDOWS then
    cmd = 'dir /b "' .. d .. '" 2>NUL'
  else
    cmd = 'ls -1 "' .. d .. '" 2>/dev/null'
  end
  local pipe = io.popen(cmd, "r")
  if not pipe then
    return found
  end
  local entries = {}
  for line in pipe:lines() do
    if line ~= "" then
      entries[#entries + 1] = line
    end
  end
  pipe:close()
  for _, name in ipairs(entries) do
    local path = d .. SEP .. name
    if isdir(path) then
      local nested = find_files(path, pattern)
      for _, p in ipairs(nested) do
        found[#found + 1] = p
      end
    elseif name:match "%.lua$" and name:match(pattern) then
      found[#found + 1] = path
    end
  end
  return found
end

--- Merge table `src` into `dst` (shallow, src wins).
local function merge(dst, src)
  if not src then
    return dst
  end
  for k, v in pairs(src) do
    dst[k] = v
  end
  return dst
end

---------------------------------------------------------------------------
-- Config loading (.chrono)
---------------------------------------------------------------------------

local function load_config()
  local f = io.open(".chrono", "r")
  if not f then
    return nil
  end
  f:close()

  local chunk, err = loadfile ".chrono"
  if not chunk then
    die("error loading .chrono config: " .. tostring(err))
  end

  local ok, cfg = pcall(chunk)
  if not ok then
    die("error executing .chrono config: " .. tostring(cfg))
  end
  if type(cfg) ~= "table" then
    die ".chrono must return a table"
  end
  return cfg
end

---------------------------------------------------------------------------
-- Argument parsing
---------------------------------------------------------------------------

local function parse_args(argv)
  local opts = { files = {}, roots = {} }
  local i = 1
  while i <= #argv do
    local a = argv[i]
    if a == "--help" or a == "-h" then
      io.write(USAGE)
      os.exit(0)
    elseif a == "--lua" then
      i = i + 1
      if not argv[i] then
        die "--lua requires an interpreter name or path"
      end
      opts.lua = argv[i]
    elseif a == "--file" then
      i = i + 1
      if not argv[i] then
        die "--file requires a path"
      end
      opts.files[#opts.files + 1] = argv[i]
    elseif a == "--root" then
      i = i + 1
      if not argv[i] then
        die "--root requires a directory"
      end
      opts.roots[#opts.roots + 1] = argv[i]
    elseif a == "--pattern" then
      i = i + 1
      if not argv[i] then
        die "--pattern requires a Lua pattern"
      end
      opts.pattern = argv[i]
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
      -- Treat bare arguments as files
      opts.files[#opts.files + 1] = a
    end
    i = i + 1
  end
  return opts
end

---------------------------------------------------------------------------
-- Suite runner
---------------------------------------------------------------------------

local function load_suite(path)
  local chunk, load_err = loadfile(path)
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
      path
        .. ": benchmark file must return a suite (got "
        .. type(suite)
        .. "). Use 'return suite' at the end of the file."
    )
  end
  return suite
end

---------------------------------------------------------------------------
-- Main
---------------------------------------------------------------------------

function M.main(argv)
  -- 0. Re-exec under a different interpreter if --lua was given
  do
    local i = 1
    while argv and i <= #argv do
      if argv[i] == "--lua" and argv[i + 1] then
        local interp = argv[i + 1]
        -- Build new argv without --lua <interp>
        local new_argv = {}
        for j = 1, #argv do
          if j ~= i and j ~= i + 1 then
            new_argv[#new_argv + 1] = argv[j]
          end
        end
        -- Re-exec: <interp> <script> <remaining args>
        local script = arg and arg[0] or "chrono"
        local parts = { interp, script }
        for _, a in ipairs(new_argv) do
          -- Quote arguments containing spaces
          if a:match "%s" then
            parts[#parts + 1] = '"' .. a .. '"'
          else
            parts[#parts + 1] = a
          end
        end
        local cmd = table.concat(parts, " ")
        os.exit(os.execute(cmd))
      end
      i = i + 1
    end
  end

  -- 1. Load .chrono config
  local cfg = load_config()
  local profile = cfg and (cfg.default or cfg) or {}

  -- 2. Start with defaults, layer config, then CLI args
  local config = {}
  merge(config, DEFAULTS)
  merge(config, profile)

  local cli = parse_args(argv or {})

  -- CLI overrides
  if cli.format then
    config.format = cli.format
  end
  if cli.timer_source then
    config.timer_source = cli.timer_source
  end
  if cli.iterations then
    config.iterations = cli.iterations
  end
  if cli.warmup then
    config.warmup = cli.warmup
  end
  if cli.min_time then
    config.min_time = cli.min_time
  end
  if cli.batch_size then
    config.batch_size = cli.batch_size
  end
  if cli.gc_off then
    config.gc_off = true
  end
  if cli.gc_collect then
    config.gc_collect = true
  end
  if cli.randomize then
    config.randomize = true
  end
  if cli.out_of_process then
    config.out_of_process = true
  end
  if cli.pattern then
    config.pattern = cli.pattern
  end

  local roots = #cli.roots > 0 and cli.roots or config.ROOT
  local files = cli.files

  -- 3. Discover benchmark files if none given explicitly
  if #files == 0 then
    for _, root in ipairs(roots) do
      local discovered = find_files(root, config.pattern)
      for _, f in ipairs(discovered) do
        files[#files + 1] = f
      end
    end
  end

  if #files == 0 then
    local dirs = table.concat(roots, ", ")
    die(
      "no benchmark files found. Searched: "
        .. dirs
        .. " (pattern: "
        .. config.pattern
        .. ")"
    )
  end

  -- Sort for deterministic order (shuffling happens inside the suite)
  table.sort(files)

  -- 4. Build run-time options
  local run_opts = {}
  if config.timer_source then
    run_opts.timer_source = config.timer_source
  end
  if config.iterations then
    run_opts.iterations = config.iterations
  end
  if config.warmup then
    run_opts.warmup = config.warmup
  end
  if config.min_time then
    run_opts.min_time = config.min_time
  end
  if config.batch_size then
    run_opts.batch_size = config.batch_size
  end
  if config.gc_off then
    run_opts.gc_off = true
  end
  if config.gc_collect then
    run_opts.gc_collect = true
  end
  if config.randomize then
    run_opts.randomize = true
  end
  if config.out_of_process then
    run_opts.out_of_process = true
  end

  -- 5. Load and run each benchmark file
  local all_results = {}
  for _, path in ipairs(files) do
    local suite = load_suite(path)
    if config.out_of_process then
      run_opts.bench_file = path
    end
    local results = suite:run(run_opts)
    all_results[#all_results + 1] = results
  end

  -- 6. Report
  for _, results in ipairs(all_results) do
    chrono.report(results, config.format)
  end
end

return M
