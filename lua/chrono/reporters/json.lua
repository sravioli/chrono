--- chrono.reporters.json: Machine-readable JSON formatter.

local M = {}

local huge = math.huge
local concat = table.concat
local format = string.format
local byte = string.byte

---------------------------------------------------------------------------
-- Minimal JSON encoder (no external dependencies)
---------------------------------------------------------------------------

local esc_map = {
  ['"'] = '\\"',
  ["\\"] = "\\\\",
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
}

local function escape_char(c)
  return esc_map[c] or format("\\u%04x", byte(c))
end

local function encode_string(s)
  return '"' .. s:gsub('[%c"\\]', escape_char) .. '"'
end

local function is_array(t)
  local n = #t
  if n == 0 then
    return next(t) == nil
  end
  local count = 0
  for _ in pairs(t) do
    count = count + 1
    if count > n then
      return false
    end
  end
  return count == n
end

local function sorted_keys(t)
  local keys = {}
  for k in pairs(t) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)
  return keys
end

local encode -- forward declaration

local function pad(level)
  return string.rep("  ", level)
end

function encode(val, level)
  level = level or 0
  local t = type(val)

  if val == nil then
    return "null"
  elseif t == "boolean" then
    return val and "true" or "false"
  elseif t == "number" then
    if val ~= val then
      return '"NaN"'
    end
    if val == huge then
      return '"Infinity"'
    end
    if val == -huge then
      return '"-Infinity"'
    end
    return format("%.14g", val)
  elseif t == "string" then
    return encode_string(val)
  elseif t == "table" then
    local inner = pad(level + 1)
    local outer = pad(level)

    if is_array(val) then
      if #val == 0 then
        return "[]"
      end
      local items = {}
      for i = 1, #val do
        items[i] = inner .. encode(val[i], level + 1)
      end
      return "[\n" .. concat(items, ",\n") .. "\n" .. outer .. "]"
    else
      local keys = sorted_keys(val)
      if #keys == 0 then
        return "{}"
      end
      local items = {}
      for _, k in ipairs(keys) do
        items[#items + 1] = inner
          .. encode_string(tostring(k))
          .. ": "
          .. encode(val[k], level + 1)
      end
      return "{\n" .. concat(items, ",\n") .. "\n" .. outer .. "}"
    end
  else
    return encode_string(tostring(val))
  end
end

--- Format a result table as pretty-printed JSON.
function M.format(result)
  return encode(result, 0)
end

return M
