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
  defer_print = false,
  repeat_count = 1,
  seed = nil,
  list = false,
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

usage: chrono [options] [path ...]
  chrono [options] --root <dir> [--root <dir> ...]
  chrono [options] -- [path ...]

General options
  --help, -h           show this message and exit
  --version            print version and exit
  --lua <interp>       re-run under a different interpreter

Input and discovery options
  --file <path>        benchmark file to run (repeatable)
  --root <dir>         root directory for auto-discovery (repeatable)
  --pattern <pat>      Lua filename pattern for discovery (default: _bench)
  --helper <path>      helper script to run before discovery (repeatable)
  --list               list benchmark names without running

Notes
  Bare positional arguments may be benchmark files or discovery directories.
  Use -- to stop option parsing; all following args are treated as paths.

Execution options
  --timer <src>        timer source: wall, cpu (default: wall)
  --iterations <n>     measurement iterations per benchmark (default: 100)
  --warmup <n>         warmup iterations per benchmark (default: 0)
  --min-time <sec>     minimum measurement time in seconds (default: 0)
  --batch-size <n>     calls per timed iteration (default: 1)
  --gc-off             disable GC during measurement
  --gc-collect         force GC between suite benchmarks
  --randomize          randomize benchmark execution order
  --seed <n>           seed randomization for deterministic runs
  --repeat <n>         repeat the entire run N times
  --out-of-process     run each benchmark in a child process

Output options
  --format <fmt>       output format: text, json, pretty (default: text)
  --[no-]defer-print   defer suite output, or stream benchmark-by-benchmark

Selection options
  --filter <pat>       include benchmark names matching Lua pattern
  --filter-out <pat>   exclude benchmark names matching Lua pattern
  --name <name>        run only the benchmark with this full name
  --tags <a,b>         include benchmarks with any listed tag
  --exclude-tags <a,b> exclude benchmarks with any listed tag

Config
  If a .chrono file exists in the working directory, Chrono loads it as a Lua
  table (similar to busted's .busted). CLI flags override config values.
  Named profiles are supported; the "default" profile is used automatically.

Auto-discovery
  If no --file is provided, Chrono searches ROOT directories (default: bench/)
  for .lua files whose names match PATTERN (default: _bench).
]]

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function die(msg)
  io.stderr:write(
    "Error: "
      .. msg
      .. "\n\n"
      .. "usage: chrono [options] [path ...]\n"
      .. "Try 'chrono --help' for full usage.\n"
  )
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

local function write_chunk(text, blank_after)
  if not text or text == "" then
    return
  end
  io.write(text)
  if blank_after then
    io.write "\n\n"
  else
    io.write "\n"
  end
  io.flush()
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
    if a == "--" then
      for j = i + 1, #argv do
        local path = argv[j]
        if isdir(path) then
          opts.roots[#opts.roots + 1] = path
        else
          opts.files[#opts.files + 1] = path
        end
      end
      break
    elseif a == "--help" or a == "-h" then
      io.write(USAGE)
      os.exit(0)
    elseif a == "--version" then
      io.write(chrono._VERSION .. "\n")
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
    elseif a == "--defer-print" then
      opts.defer_print = true
    elseif a == "--no-defer-print" then
      opts.defer_print = false
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
    elseif a == "--filter" then
      i = i + 1
      if not argv[i] then
        die "--filter requires a Lua pattern"
      end
      opts.filter = argv[i]
    elseif a == "--filter-out" then
      i = i + 1
      if not argv[i] then
        die "--filter-out requires a Lua pattern"
      end
      opts.filter_out = argv[i]
    elseif a == "--name" then
      i = i + 1
      if not argv[i] then
        die "--name requires a benchmark name"
      end
      opts.name = argv[i]
    elseif a == "--tags" then
      i = i + 1
      if not argv[i] then
        die "--tags requires a comma-separated list"
      end
      opts.tags = {}
      for tag in string.gmatch(argv[i], "[^,]+") do
        opts.tags[#opts.tags + 1] = tag
      end
    elseif a == "--exclude-tags" then
      i = i + 1
      if not argv[i] then
        die "--exclude-tags requires a comma-separated list"
      end
      opts.exclude_tags = {}
      for tag in string.gmatch(argv[i], "[^,]+") do
        opts.exclude_tags[#opts.exclude_tags + 1] = tag
      end
    elseif a == "--helper" then
      i = i + 1
      if not argv[i] then
        die "--helper requires a path"
      end
      opts.helpers = opts.helpers or {}
      opts.helpers[#opts.helpers + 1] = argv[i]
    elseif a == "--seed" then
      i = i + 1
      opts.seed = tonumber(argv[i])
      if not opts.seed then
        die "--seed requires a number"
      end
    elseif a == "--repeat" then
      i = i + 1
      opts.repeat_count = tonumber(argv[i])
      if not opts.repeat_count or opts.repeat_count < 1 then
        die "--repeat requires a positive integer"
      end
    elseif a == "--list" then
      opts.list = true
    elseif a == "--out-of-process" then
      opts.out_of_process = true
    else
      -- Treat bare arguments as files or discovery roots.
      if isdir(a) then
        opts.roots[#opts.roots + 1] = a
      else
        opts.files[#opts.files + 1] = a
      end
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
  if cli.defer_print ~= nil then
    config.defer_print = cli.defer_print
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
  if cli.seed then
    config.seed = cli.seed
  end
  if cli.repeat_count then
    config.repeat_count = cli.repeat_count
  end

  if config.format == "json" then
    config.defer_print = true
  end

  local explicit_roots = #cli.roots > 0
  local roots = explicit_roots and cli.roots or config.ROOT
  local files = cli.files

  -- Run helper scripts (if any) before discovery
  if cli.helpers then
    for _, h in ipairs(cli.helpers) do
      local chunk, err = loadfile(h)
      if not chunk then
        die("error loading helper: " .. tostring(err))
      end
      local ok, res = pcall(chunk)
      if not ok then
        die("error running helper: " .. tostring(res))
      end
    end
  end

  -- 3. Discover benchmark files from explicit roots, or from config roots when
  --    no files were given.
  if explicit_roots or #files == 0 then
    for _, root in ipairs(roots) do
      local discovered = find_files(root, config.pattern)
      for _, f in ipairs(discovered) do
        files[#files + 1] = f
      end
    end
  end

  do
    local seen = {}
    local unique = {}
    for _, path in ipairs(files) do
      if not seen[path] then
        seen[path] = true
        unique[#unique + 1] = path
      end
    end
    files = unique
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

  -- If list mode requested, print benchmark names and exit
  if cli.list then
    for _, path in ipairs(files) do
      local suite = load_suite(path)
      io.write(path .. "\n")
      for _, b in ipairs(suite._benchmarks) do
        io.write("  " .. b.name .. "\n")
      end
    end
    return
  end

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
  if config.seed then
    run_opts.seed = config.seed
  end
  -- Forward helper scripts to child processes
  if cli.helpers then
    run_opts.helpers = cli.helpers
  elseif config.helpers then
    run_opts.helpers = config.helpers
  end

  local repeat_count = config.repeat_count or 1

  local reporter = chrono.get_reporter(config.format)
  local can_stream = not config.defer_print
    and config.format ~= "json"
    and reporter.start_suite
    and reporter.format_benchmark
    and reporter.finish_suite

  -- 5. Load and run each benchmark file (possibly repeated)
  local all_results = {}
  for rep = 1, repeat_count do
    if repeat_count > 1 then
      -- adjust seed per repetition for deterministic but distinct shuffles
      if config.seed then
        run_opts.seed = config.seed + (rep - 1)
      end
      run_opts.run_index = rep
      run_opts.run_count = repeat_count
    end
    for index, path in ipairs(files) do
      local suite = load_suite(path)
      -- Apply simple name/pattern/tags filters from CLI
      if cli.filter then
        suite:filter(function(name)
          if not name:match(cli.filter) then
            return true, "filter"
          end
          return false
        end)
      end
      if cli.filter_out then
        suite:filter(function(name)
          if name:match(cli.filter_out) then
            return true, "filter-out"
          end
          return false
        end)
      end
      if cli.name then
        suite:filter(function(name)
          if name ~= cli.name then
            return true, "name mismatch"
          end
          return false
        end)
      end
      if cli.exclude_tags then
        local excl = {}
        for _, t in ipairs(cli.exclude_tags) do
          excl[t] = true
        end
        suite:filter(function(_, opts)
          if not opts or not opts.tags then
            return false
          end
          for _, t in ipairs(opts.tags) do
            if excl[t] then
              return true, "exclude-tag"
            end
          end
          return false
        end)
      end
      if cli.tags then
        local incl = {}
        for _, t in ipairs(cli.tags) do
          incl[t] = true
        end
        suite:filter(function(_, opts)
          if not opts or not opts.tags then
            return true, "no-tag"
          end
          for _, t in ipairs(opts.tags) do
            if incl[t] then
              return false
            end
          end
          return true, "tag-missing"
        end)
      end
      if config.out_of_process then
        run_opts.bench_file = path
      end
      if can_stream then
        local header_written = false
        run_opts.on_benchmark_result = function(result, bench_index, _, partial_results)
          if not header_written then
            write_chunk(reporter.start_suite(partial_results), true)
            header_written = true
          end
          write_chunk(reporter.format_benchmark(result, bench_index), true)
        end

        local results = suite:run(run_opts)
        run_opts.on_benchmark_result = nil

        if not header_written then
          write_chunk(reporter.start_suite(results), true)
        end
        write_chunk(reporter.finish_suite(results), index < #files)
      else
        run_opts.on_benchmark_result = nil
        local results = suite:run(run_opts)
        all_results[#all_results + 1] = results
      end
    end
  end

  -- 6. Report
  for _, results in ipairs(all_results) do
    chrono.report(results, config.format)
  end
end

return M
