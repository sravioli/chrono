#!/usr/bin/env lua
--- bump-rockspecs.lua — generate versioned rockspecs from scm templates.
--- Called by cocogitto pre_bump_hooks with the new version as arg[1].
---
--- Usage: lua scripts/bump-rockspecs.lua 1.0.0

local version = arg and arg[1]
if not version then
  io.stderr:write("Usage: lua scripts/bump-rockspecs.lua <version>\n")
  os.exit(1)
end

local sep = package.config:sub(1, 1)

local function mkdir(path)
  if sep == "\\" then
    os.execute('if not exist "' .. path .. '" mkdir "' .. path .. '"')
  else
    os.execute('mkdir -p "' .. path .. '"')
  end
end

local function readfile(path)
  local f = assert(io.open(path, "r"))
  local content = f:read("*a")
  f:close()
  return content
end

local function writefile(path, content)
  local f = assert(io.open(path, "w"))
  f:write(content)
  f:close()
end

local scm_specs = {}
for _, name in ipairs({ "chrono-scm-1.rockspec", "chrono-clock-scm-1.rockspec" }) do
  local f = io.open(name, "r")
  if f then
    f:close()
    scm_specs[#scm_specs + 1] = name
  end
end

if #scm_specs == 0 then
  io.stderr:write("No scm rockspecs found in working directory\n")
  os.exit(1)
end

mkdir("rockspecs")

for _, scm in ipairs(scm_specs) do
  local pkg = scm:match("^(.+)-scm%-1%.rockspec$")
  local dest = "rockspecs" .. sep .. pkg .. "-" .. version .. "-1.rockspec"

  local content = readfile(scm)
  content = content:gsub('version = "scm%-1"', 'version = "' .. version .. '-1"')
  content = content:gsub(
    'url = "git%+https://github%.com/sravioli/chrono%.git"',
    'url = "git+https://github.com/sravioli/chrono.git",\n  tag = "' .. version .. '"'
  )

  writefile(dest, content)
  print("Created " .. dest)
end
