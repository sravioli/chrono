--- Specs for tag-based filtering behavior (mirrors CLI --tags / --exclude-tags logic)

local chrono = require "chrono"

describe("tag filtering", function()
  local noop = function() end

  it("includes only benchmarks with matching tags", function()
    local s = chrono.suite("inc", { iterations = 3 })
    s:add("fastcase", noop, { tags = { "fast", "unit" } })
    s:add("slowcase", noop, { tags = { "slow" } })

    -- Simulate CLI --tags=fast
    local incl = {}
    incl["fast"] = true
    s:filter(function(_, opts)
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

    local results = s:run()
    assert.are.equal(1, #results.benchmarks)
    assert.are.equal("fastcase", results.benchmarks[1].name)
    -- ensure non-matching benchmarks were skipped
    assert.is_truthy(results.skipped and #results.skipped >= 1)
    assert.are.equal("slowcase", results.skipped[1].name)
  end)

  it("excludes benchmarks with any exclude tag", function()
    local s = chrono.suite("exc", { iterations = 3 })
    s:add("a", noop, { tags = { "foo" } })
    s:add("b", noop, { tags = { "bar" } })

    -- Simulate CLI --exclude-tags=bar
    local excl = { bar = true }
    s:filter(function(_, opts)
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

    local results = s:run()
    assert.are.equal(1, #results.benchmarks)
    assert.are.equal("a", results.benchmarks[1].name)
    -- verify skipped contains the excluded benchmark
    assert.is_truthy(results.skipped and #results.skipped >= 1)
    local found = false
    for _, v in ipairs(results.skipped) do
      if v.name == "b" then
        found = true
        assert.are.equal("exclude-tag", v.reason)
      end
    end
    assert.is_true(found)
  end)
end)
