-- Update the `M._VERSION` value in lua/chrono/init.lua
local version = arg and arg[1]
if not version then
  io.stderr:write "Usage: bump-chrono-version.lua <version>\n"
  os.exit(2)
end

local path = "lua/chrono/init.lua"
local f, err = io.open(path, "r")
if not f then
  io.stderr:write("Cannot open " .. path .. ": " .. tostring(err) .. "\n")
  os.exit(1)
end
local content = f:read "*a"
f:close()

local pattern = 'M%._VERSION%s*=%s*"(.-)"'
local new_content, n = content:gsub(pattern, 'M._VERSION = "' .. version .. '"', 1)
if n == 0 then
  io.stderr:write("Version pattern not found in " .. path .. "\n")
  os.exit(1)
end

local out, err = io.open(path, "w")
if not out then
  io.stderr:write("Cannot write to " .. path .. ": " .. tostring(err) .. "\n")
  os.exit(1)
end
out:write(new_content)
out:close()

print("Updated " .. path .. " to " .. version)

return 0
