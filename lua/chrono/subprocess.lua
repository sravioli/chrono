--- chrono.subprocess: Out-of-process benchmark execution.
-- Runs each benchmark in an isolated child process, collecting results via
-- JSON over stdout.  Requires io.popen (available in PUC Lua and LuaJIT).

local timer = require "chrono.timer"

local M = {}

--- Detect the Lua interpreter that launched the current process.
-- @return string  path to the interpreter
local function interpreter()
  -- arg[-1] is the interpreter on both PUC Lua and LuaJIT
  if arg and arg[-1] then
    return arg[-1]
  end
  -- Best-effort fallback
  return timer.is_luajit and "luajit" or "lua"
end

--- Locate the chrono package root (directory containing lua/).
-- @return string
local function chrono_root()
  -- chrono.subprocess is at <root>/lua/chrono/subprocess.lua
  -- __FILE__ trick: not available in vanilla Lua, so derive from package.searchpath
  local path = package.searchpath("chrono.subprocess", package.path)
  if path then
    -- Strip lua/chrono/subprocess.lua  ->  <root>
    -- Normalise separators first
    path = path:gsub("\\", "/")
    local root = path:match "^(.+)/lua/chrono/subprocess%.lua$"
    if root then
      return root
    end
  end
  -- Fallback: assume cwd is the chrono root
  return "."
end

local _root -- cached

--- Build the preamble that lets the child process find the chrono package.
local function child_preamble()
  if not _root then
    _root = chrono_root()
  end
  local r = _root
  return string.format(
    "package.path=%q;package.cpath=%q;",
    r .. "/lua/?.lua;" .. r .. "/lua/?/init.lua;" .. package.path,
    r .. "/c/?.so;" .. r .. "/c/?.dll;" .. package.cpath
  )
end

--- Run a single benchmark in a child process.
-- @param name string          benchmark display name
-- @param bench_file string    path to the benchmark file (must return a suite)
-- @param bench_name string    name of the specific benchmark within the suite
-- @param opts table           runner options
-- @return table               result (statistics or error)
function M.run_single(name, bench_file, bench_name, opts)
  local preamble = child_preamble()
  local lua = interpreter()

  -- Serialize opts into a Lua literal so the child can reconstruct it.
  local function serialize(v)
    local t = type(v)
    if t == "number" then
      return tostring(v)
    elseif t == "boolean" then
      return tostring(v)
    elseif t == "string" then
      return string.format("%q", v)
    elseif t == "table" then
      -- Detect array-like vs map-like
      local is_array = true
      for k, _ in pairs(v) do
        if type(k) ~= "number" then
          is_array = false
          break
        end
      end
      local parts = {}
      if is_array then
        for i = 1, #v do
          parts[#parts + 1] = serialize(v[i])
        end
        return "{" .. table.concat(parts, ",") .. "}"
      else
        for k, val in pairs(v) do
          parts[#parts + 1] = string.format("[%q]=%s", tostring(k), serialize(val))
        end
        return "{" .. table.concat(parts, ",") .. "}"
      end
    else
      return "nil"
    end
  end

  local opts_str = serialize(opts or {})

  local script = string.format(
    [[
%s
local chrono=require("chrono");local json=require("chrono.reporters.json");
local opts = %s;
if opts and opts.helpers then
  for _,h in ipairs(opts.helpers) do
    local chunk, err = loadfile(h)
    if not chunk then io.write(json.format({name=%q,error=err}));os.exit(0) end
    local ok, res = pcall(chunk)
    if not ok then io.write(json.format({name=%q,error=tostring(res)}));os.exit(0) end
  end
end
local chunk,err=loadfile(%q);
if not chunk then io.write(json.format({name=%q,error=err}));os.exit(0) end;
local ok,suite=pcall(chunk);
if not ok then io.write(json.format({name=%q,error=tostring(suite)}));os.exit(0) end;
local found;
for _,b in ipairs(suite._benchmarks) do if b.name==%q then found=b;break end end;
if not found then io.write(json.format({name=%q,error='benchmark not found'}));os.exit(0) end;
local runner=require("chrono.runner");local r=runner.run_single(found.name,found.fn,opts);
io.write(json.format(r))
]],
    preamble,
    opts_str,
    bench_name,
    bench_name,
    bench_file,
    bench_name,
    bench_name,
    bench_name,
    bench_name
  )

  local cmd = string.format("%s -e %q 2>&1", lua, script)
  local handle = io.popen(cmd, "r")
  if not handle then
    return { name = name, error = "failed to spawn child process", timer_source = "N/A" }
  end

  local output = handle:read "*a"
  local _, exit_reason, exit_code = handle:close()

  if not output or output == "" then
    return {
      name = name,
      error = string.format(
        "child process produced no output (exit: %s %s)",
        tostring(exit_reason),
        tostring(exit_code)
      ),
      timer_source = "N/A",
    }
  end

  -- Parse the JSON output back into a Lua table.
  -- We reuse our json reporter's format — the output is a Lua-friendly JSON.
  -- Parse it with a safe loader.
  local result = M._parse_child_output(output, name)
  return result
end

--- Parse child process JSON output into a result table.
-- @param output string  raw stdout from child
-- @param name   string  fallback name
-- @return table
function M._parse_child_output(output, name)
  -- Convert our JSON subset back to a Lua table.
  -- Our JSON uses: "key": value — convert to ["key"] = value
  local lua_src = output
  lua_src = lua_src:gsub('"NaN"', "(0/0)")
  lua_src = lua_src:gsub('"Infinity"', "(1/0)")
  lua_src = lua_src:gsub('"-Infinity"', "(-1/0)")
  lua_src = lua_src:gsub('"([^"\\]-)":%s*', function(k)
    return '["' .. k .. '"] = '
  end)
  lua_src = lua_src:gsub("null", "nil")
  lua_src = "return " .. lua_src

  -- Load in a restricted sandbox (no access to globals)
  local fn, err
  if setfenv then
    -- Lua 5.1 / LuaJIT
    fn, err = loadstring(lua_src)
    if fn then
      setfenv(fn, {})
    end
  else
    -- Lua 5.2+
    fn, err = load(lua_src, "=child_output", "t", {})
  end

  if not fn then
    return {
      name = name,
      error = "failed to parse child output: " .. tostring(err),
      timer_source = "N/A",
    }
  end

  local ok, result = pcall(fn)
  if not ok or type(result) ~= "table" then
    return {
      name = name,
      error = "invalid child output: " .. tostring(result),
      timer_source = "N/A",
    }
  end

  return result
end

return M
