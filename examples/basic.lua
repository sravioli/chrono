--- Example: Using chrono as a library.
--
-- Run from the chrono/ directory:
--   lua examples/basic.lua

-- Adjust package.path so require("chrono") resolves correctly.
do
	local dir = (arg and arg[0] or "."):match("^(.+)[/\\]") or "."
	-- examples/ is inside chrono/; the lua/ subdirectory holds the package
	package.path = dir .. "/../lua/?.lua;" .. dir .. "/../lua/?/init.lua;" .. package.path
	package.cpath = dir .. "/../c/?.so;" .. dir .. "/../c/?.dll;" .. package.cpath
end

local chrono = require("chrono")

-- Create a suite with default options
local suite = chrono.suite("String Operations", {
	iterations = 500,
	warmup = 50,
})

-- Benchmark: naive string concatenation
suite:add("concatenation (..)", function()
	local s = ""
	for i = 1, 100 do
		s = s .. "x"
	end
end)

-- Benchmark: table.concat
suite:add("table.concat", function()
	local t = {}
	for i = 1, 100 do
		t[i] = "x"
	end
	local _ = table.concat(t)
end)

-- Benchmark: string.rep
suite:add("string.rep", function()
	local _ = string.rep("x", 100)
end)

-- Run and report
local results = suite:run()

io.write("=== Text Output ===\n\n")
chrono.report(results, "text")

io.write("\n=== JSON Output ===\n\n")
chrono.report(results, "json")
