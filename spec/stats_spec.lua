--- Correctness tests for chrono.statistics

local statistics = require "chrono.statistics"

local function approx(a, b, tol)
  tol = tol or 1e-9
  return math.abs(a - b) <= tol
end

describe("statistics.compute", function()
  describe("with empty samples", function()
    it("returns n == 0", function()
      local r = statistics.compute {}
      assert.are.equal(0, r.n)
    end)

    it("returns an error message", function()
      local r = statistics.compute {}
      assert.is_string(r.error)
    end)
  end)

  describe("with a single sample", function()
    local r

    before_each(function()
      r = statistics.compute { 0.5 }
    end)

    it("reports n == 1", function()
      assert.are.equal(1, r.n)
    end)

    it("sets mean to the sample value", function()
      assert.are.equal(0.5, r.mean)
    end)

    it("sets min and max to the sample value", function()
      assert.are.equal(0.5, r.min)
      assert.are.equal(0.5, r.max)
    end)

    it("reports zero standard deviation", function()
      assert.are.equal(0, r.stddev)
    end)

    it("sets median to the sample value", function()
      assert.are.equal(0.5, r.median)
    end)

    it("computes ops_sec as 1 / mean", function()
      assert.is_true(approx(r.ops_sec, 2.0))
    end)
  end)

  describe("with two identical samples", function()
    it("reports zero standard deviation", function()
      local r = statistics.compute { 7, 7 }
      assert.are.equal(0, r.stddev)
    end)

    it("reports the correct mean", function()
      local r = statistics.compute { 7, 7 }
      assert.are.equal(7, r.mean)
    end)
  end)

  describe("with a five-element dataset {1,2,3,4,5}", function()
    local r

    before_each(function()
      r = statistics.compute { 1, 2, 3, 4, 5 }
    end)

    it("reports n == 5", function()
      assert.are.equal(5, r.n)
    end)

    it("computes the arithmetic mean", function()
      assert.is_true(approx(r.mean, 3.0))
    end)

    it("finds the minimum", function()
      assert.are.equal(1, r.min)
    end)

    it("finds the maximum", function()
      assert.are.equal(5, r.max)
    end)

    it("computes Bessel-corrected standard deviation", function()
      -- sample stddev = sqrt(10/4) = sqrt(2.5)
      assert.is_true(approx(r.stddev, math.sqrt(2.5), 1e-6))
    end)

    it("computes the median", function()
      assert.is_true(approx(r.median, 3.0))
    end)

    it("computes ops_sec as 1 / mean", function()
      assert.is_true(approx(r.ops_sec, 1 / 3.0, 1e-6))
    end)
  end)

  describe("with a 100-element dataset (1..100)", function()
    local r

    before_each(function()
      local samples = {}
      for i = 1, 100 do
        samples[i] = i
      end
      r = statistics.compute(samples)
    end)

    it("reports n == 100", function()
      assert.are.equal(100, r.n)
    end)

    it("computes mean == 50.5", function()
      assert.is_true(approx(r.mean, 50.5))
    end)

    it("finds min == 1", function()
      assert.are.equal(1, r.min)
    end)

    it("finds max == 100", function()
      assert.are.equal(100, r.max)
    end)

    it("computes median == 50", function()
      assert.are.equal(50, r.median)
    end)

    it("computes p95 == 95", function()
      assert.are.equal(95, r.p95)
    end)

    it("computes p99 == 99", function()
      assert.are.equal(99, r.p99)
    end)
  end)

  describe("edge cases", function()
    it("returns ops_sec == inf when mean is zero", function()
      local r = statistics.compute { 0 }
      assert.are.equal(math.huge, r.ops_sec)
    end)

    it("handles very small values without losing precision", function()
      local r = statistics.compute { 1e-9, 2e-9, 3e-9 }
      assert.is_true(approx(r.mean, 2e-9))
      assert.are.equal(1e-9, r.min)
      assert.are.equal(3e-9, r.max)
    end)

    it("does not mutate the original samples array", function()
      local samples = { 5, 3, 1, 4, 2 }
      statistics.compute(samples)
      assert.are.equal(5, samples[1])
      assert.are.equal(3, samples[2])
      assert.are.equal(1, samples[3])
      assert.are.equal(4, samples[4])
      assert.are.equal(2, samples[5])
    end)

    it("produces correct percentiles on unsorted input", function()
      local r = statistics.compute { 5, 3, 1, 4, 2 }
      assert.is_true(approx(r.median, 3.0))
      assert.are.equal(1, r.min)
      assert.are.equal(5, r.max)
    end)

    it("computes stddev correctly for large n", function()
      local samples = {}
      for i = 1, 1000 do
        samples[i] = i
      end
      local r = statistics.compute(samples)
      -- Bessel-corrected sample stddev for 1..N: sqrt(N*(N+1)/12)
      local expected = math.sqrt(1000 * 1001 / 12)
      assert.is_true(approx(r.stddev, expected, 0.01))
    end)
  end)
end)
