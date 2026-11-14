-- Kraft runtime. Встраивается в сгенерированный Lua целиком.
-- Никаких зависимостей, кроме LuaJIT (Lua 5.1).

local krt = {}

-- NONE — отдельное значение, а не nil: nil нельзя положить в список/словарь.
krt.NONE = setmetatable({}, { __tostring = function() return "NONE" end })

local LIST_MT = { __kraft = "list" }
local DICT_MT = { __kraft = "dict" }

function krt.list(t) return setmetatable(t or {}, LIST_MT) end
function krt.dict() return setmetatable({ keys = {}, vals = {} }, DICT_MT) end
function krt.is_list(v) return type(v) == "table" and getmetatable(v) == LIST_MT end
function krt.is_dict(v) return type(v) == "table" and getmetatable(v) == DICT_MT end

-- ---------- числа ----------

local function is_integral(n)
  return n == math.floor(n) and math.abs(n) < 1e15
end

function krt.num_to_str(n)
  if n ~= n then return "nan" end
  if n == math.huge then return "inf" end
  if n == -math.huge then return "-inf" end
  if is_integral(n) then return string.format("%d", n) end
  return string.format("%.14g", n)
end

-- ---------- печать значений ----------

local function quote(s)
  s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
  return '"' .. s .. '"'
end

function krt.tostr(v)
  local t = type(v)
  if v == nil or v == krt.NONE then return "NONE" end
  if t == "string" then return v end
  if t == "number" then return krt.num_to_str(v) end
  if t == "boolean" then return v and "TRUE" or "FALSE" end
  if t == "table" then
    if krt.is_list(v) then
      local out = {}
      for i = 1, #v do out[i] = krt.tostr_inner(v[i]) end
      return "[" .. table.concat(out, ", ") .. "]"
    elseif krt.is_dict(v) then
      local out = {}
      for i = 1, #v.keys do
        out[i] = v.keys[i] .. ": " .. krt.tostr_inner(v.vals[i])
      end
      return "{" .. table.concat(out, ", ") .. "}"
    end
  end
  return tostring(v)
end

-- Внутри коллекций строки печатаются в кавычках.
function krt.tostr_inner(v)
  if type(v) == "string" then return quote(v) end
  return krt.tostr(v)
end

-- ---------- вывод ----------

function krt.show(s)
  io.write(s, "\n")
  return krt.NONE
end

function krt.show_err(s)
  io.stderr:write(s, "\n")
  return krt.NONE
end

function krt.input(prompt)
  if prompt and prompt ~= "" then io.write(prompt) end
  local line = io.read("*l")
  if line == nil then return "" end
  return line
end

-- ---------- истинность ----------

function krt.truthy(v)
  return v ~= nil and v ~= false and v ~= krt.NONE
end

-- ---------- арифметика с семантикой Python ----------

function krt.fail(cat, msg)
  error({ kraft_runtime = true, cat = cat, msg = msg }, 0)
end

function krt.div(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    krt.fail("TYPE_MISMATCH_ERROR", "expected flint, found " .. krt.typeof(a) .. " and " .. krt.typeof(b))
  end
  if b == 0 then krt.fail("VALUE_ERROR", "division by zero") end
  return a / b
end

function krt.idiv(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    krt.fail("TYPE_MISMATCH_ERROR", "expected flint, found " .. krt.typeof(a) .. " and " .. krt.typeof(b))
  end
  if b == 0 then krt.fail("VALUE_ERROR", "division by zero") end
  return math.floor(a / b)
end

function krt.mod(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    krt.fail("TYPE_MISMATCH_ERROR", "expected flint, found " .. krt.typeof(a) .. " and " .. krt.typeof(b))
  end
  if b == 0 then krt.fail("VALUE_ERROR", "division by zero") end
  return a - math.floor(a / b) * b
end

function krt.pow(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    krt.fail("TYPE_MISMATCH_ERROR", "expected flint, found " .. krt.typeof(a) .. " and " .. krt.typeof(b))
  end
  if a < 0 and b ~= math.floor(b) then
    krt.fail("VALUE_ERROR", "negative number to a fractional power")
  end
  return a ^ b
end

-- ---------- проверки типов в рантайме ----------

function krt.as_flint(v)
  if type(v) ~= "number" then
    krt.fail("TYPE_MISMATCH_ERROR", "expected flint, found " .. krt.typeof(v))
  end
  return v
end

function krt.as_str(v)
  if type(v) ~= "string" then
    krt.fail("TYPE_MISMATCH_ERROR", "expected str, found " .. krt.typeof(v))
  end
  return v
end

function krt.as_bool(v)
  if type(v) ~= "boolean" then
    krt.fail("TYPE_MISMATCH_ERROR", "expected bool, found " .. krt.typeof(v))
  end
  return v
end

-- ---------- типы и длина ----------

function krt.typeof(v)
  if v == nil or v == krt.NONE then return "NONE" end
  local t = type(v)
  if t == "number" then return "flint" end
  if t == "string" then return "str" end
  if t == "boolean" then return "bool" end
  if t == "table" then
    if krt.is_list(v) then return "list" end
    if krt.is_dict(v) then return "dict" end
    return "dict"
  end
  return t
end

function krt.utf8_len(s)
  local n = 0
  for i = 1, #s do
    local b = s:byte(i)
    if not (b >= 0x80 and b < 0xC0) then n = n + 1 end
  end
  return n
end

function krt.len(v)
  if type(v) == "string" then return krt.utf8_len(v) end
  if krt.is_list(v) then return #v end
  if krt.is_dict(v) then return #v.keys end
  krt.fail("TYPE_MISMATCH_ERROR", "len: expected str, list or dict, found " .. krt.typeof(v))
end

-- ---------- процесс ----------

function krt.args()
  local t = { __KRAFT_SOURCE or "" }
  if type(arg) == "table" then
    for i = 1, #arg do t[#t + 1] = arg[i] end
  end
  return krt.list(t)
end

function krt.exit(code)
  os.exit(code or 0)
end

function krt.time_ms()
  return os.clock() * 1000
end

function krt.is_tty()
  local ok, ffi = pcall(require, "ffi")
  if not ok then return false end
  pcall(ffi.cdef, "int isatty(int);")
  local ok2, r = pcall(function() return ffi.C.isatty(2) end)
  return ok2 and r == 1
end

-- ---------- запуск программы ----------

function krt.run(fn)
  local ok, err = pcall(fn)
  if ok then return end
  if type(err) == "table" and err.kraft_runtime then
    io.stderr:write(err.cat .. ": " .. err.msg .. "\n")
  else
    io.stderr:write("RUNTIME_ERROR: " .. tostring(err) .. "\n")
  end
  os.exit(1)
end

return krt
