--- Example benchmark file for CLI usage.
--
-- Run from the chrono/ directory:
--   lua cli.lua --file examples/cli_sample.lua --iterations 200

local chrono = require("chrono")

local suite = chrono.suite("Table Operations")

suite:add("append (#t + 1)", function()
	local t = {}
	for i = 1, 200 do
		t[#t + 1] = i
	end
end)

suite:add("table.insert", function()
	local t = {}
	for i = 1, 200 do
		table.insert(t, i)
	end
end)

suite:add("rawset", function()
	local t = {}
	for i = 1, 200 do
		rawset(t, i, i)
	end
end)

return suite
