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

-- ---------- строки: индексы, срезы, методы ----------

function krt.utf8_chars(s)
  local out = {}
  local i, n = 1, #s
  while i <= n do
    local b = s:byte(i)
    local len = 1
    if b >= 0xF0 then len = 4
    elseif b >= 0xE0 then len = 3
    elseif b >= 0xC0 then len = 2 end
    out[#out + 1] = s:sub(i, i + len - 1)
    i = i + len
  end
  return out
end

function krt.str_index(s, i)
  local chars = krt.utf8_chars(s)
  local n = #chars
  i = math.floor(i)
  if i < 0 then i = i + n end
  if i < 0 or i >= n then
    krt.fail("VALUE_ERROR", "string index out of range: " .. tostring(math.floor(i)))
  end
  return chars[i + 1]
end

-- Правая граница не входит; открытые границы; отрицательные индексы.
function krt.str_slice(s, from, to, step)
  local chars = krt.utf8_chars(s)
  local n = #chars
  step = step or 1
  if step ~= math.floor(step) then
    krt.fail("VALUE_ERROR", "slice step must be integer")
  end
  if step == 0 then krt.fail("VALUE_ERROR", "slice step cannot be zero") end

  local function norm(i, default)
    if i == nil then return default end
    i = math.floor(i)
    if i < 0 then i = i + n end
    if step > 0 then
      if i < 0 then i = 0 end
      if i > n then i = n end
    else
      if i < -1 then i = -1 end
      if i > n - 1 then i = n - 1 end
    end
    return i
  end

  local a = norm(from, step > 0 and 0 or n - 1)
  local b = norm(to, step > 0 and n or -1)

  local out = {}
  local i = a
  while (step > 0 and i < b) or (step < 0 and i > b) do
    out[#out + 1] = chars[i + 1]
    i = i + step
  end
  return table.concat(out)
end

function krt.str_part(s, from, to)
  return krt.str_slice(s, from, to, 1)
end

function krt.str_find(s, sub)
  local a = krt.utf8_chars(s)
  local b = krt.utf8_chars(sub)
  if #b == 0 then return 0 end
  for i = 0, #a - #b do
    local ok = true
    for j = 1, #b do
      if a[i + j] ~= b[j] then ok = false; break end
    end
    if ok then return i end
  end
  return krt.NONE
end

function krt.str_contains(s, sub)
  return krt.str_find(s, sub) ~= krt.NONE
end

function krt.str_preff(s, p)
  return s:sub(1, #p) == p
end

function krt.str_suff(s, p)
  return p == "" or s:sub(-#p) == p
end

function krt.str_trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function krt.str_triml(s)
  return (s:gsub("^%s+", ""))
end

function krt.str_trimr(s)
  return (s:gsub("%s+$", ""))
end

function krt.str_replace(s, old, new)
  if old == "" then return s end
  local out = {}
  local i = 1
  while true do
    local a, b = s:find(old, i, true)
    if not a then
      out[#out + 1] = s:sub(i)
      break
    end
    out[#out + 1] = s:sub(i, a - 1)
    out[#out + 1] = new
    i = b + 1
  end
  return table.concat(out)
end

function krt.str_count(s, sub)
  if sub == "" then return 0 end
  local count = 0
  local i = 1
  while true do
    local a, b = s:find(sub, i, true)
    if not a then break end
    count = count + 1
    i = b + 1
  end
  return count
end

-- ---------- списки ----------

function krt.as_list(v)
  if not krt.is_list(v) then
    krt.fail("TYPE_MISMATCH_ERROR", "expected list, found " .. krt.typeof(v))
  end
  return v
end

function krt.as_dict(v)
  if not krt.is_dict(v) then
    krt.fail("TYPE_MISMATCH_ERROR", "expected dict, found " .. krt.typeof(v))
  end
  return v
end

function krt.list_index(xs, i)
  local n = #xs
  i = math.floor(i)
  if i < 0 then i = i + n end
  if i < 0 or i >= n then
    krt.fail("VALUE_ERROR", "list index out of range: " .. tostring(math.floor(i)))
  end
  return xs[i + 1]
end

function krt.list_slice(xs, from, to, step)
  local n = #xs
  step = step or 1
  if step ~= math.floor(step) then
    krt.fail("VALUE_ERROR", "slice step must be integer")
  end
  if step == 0 then krt.fail("VALUE_ERROR", "slice step cannot be zero") end

  local function norm(i, default)
    if i == nil then return default end
    i = math.floor(i)
    if i < 0 then i = i + n end
    if step > 0 then
      if i < 0 then i = 0 end
      if i > n then i = n end
    else
      if i < -1 then i = -1 end
      if i > n - 1 then i = n - 1 end
    end
    return i
  end

  local a = norm(from, step > 0 and 0 or n - 1)
  local b = norm(to, step > 0 and n or -1)

  local out = krt.list({})
  local i = a
  while (step > 0 and i < b) or (step < 0 and i > b) do
    out[#out + 1] = xs[i + 1]
    i = i + step
  end
  return out
end

-- Индекс и срез значения внутреннего типа any: тип выбирается в рантайме.
function krt.index(v, i)
  if krt.is_list(v) then return krt.list_index(v, i) end
  if type(v) == "string" then return krt.str_index(v, i) end
  krt.fail("TYPE_MISMATCH_ERROR", "expected list or str, found " .. krt.typeof(v))
end

function krt.slice(v, from, to, step)
  if krt.is_list(v) then return krt.list_slice(v, from, to, step) end
  if type(v) == "string" then return krt.str_slice(v, from, to, step) end
  krt.fail("TYPE_MISMATCH_ERROR", "expected list or str, found " .. krt.typeof(v))
end

function krt.list_add(xs, v)
  xs[#xs + 1] = v
  return krt.NONE
end

function krt.list_del(xs, i)
  local n = #xs
  i = math.floor(i)
  if i < 0 then i = i + n end
  if i < 0 or i >= n then
    krt.fail("VALUE_ERROR", "list index out of range: " .. tostring(math.floor(i)))
  end
  table.remove(xs, i + 1)
  return krt.NONE
end

function krt.list_remove(xs, v)
  for i = 1, #xs do
    if xs[i] == v then
      table.remove(xs, i)
      return true
    end
  end
  return false
end

function krt.list_replace(xs, i, v)
  local n = #xs
  i = math.floor(i)
  if i < 0 then i = i + n end
  if i < 0 or i >= n then
    krt.fail("VALUE_ERROR", "list index out of range: " .. tostring(math.floor(i)))
  end
  xs[i + 1] = v
  return krt.NONE
end

function krt.list_contains(xs, v)
  for i = 1, #xs do
    if xs[i] == v then return true end
  end
  return false
end

function krt.list_count(xs, v)
  local c = 0
  for i = 1, #xs do
    if xs[i] == v then c = c + 1 end
  end
  return c
end

function krt.list_index_of(xs, v)
  for i = 1, #xs do
    if xs[i] == v then return i - 1 end
  end
  return krt.NONE
end

function krt.list_join(xs, sep)
  local out = {}
  for i = 1, #xs do out[i] = krt.tostr(xs[i]) end
  return table.concat(out, sep)
end

-- ---------- словари ----------

local function dict_pos(d, k)
  for i = 1, #d.keys do
    if d.keys[i] == k then return i end
  end
  return nil
end

function krt.dict_set(d, k, v)
  local p = dict_pos(d, k)
  if p then
    d.vals[p] = v
  else
    d.keys[#d.keys + 1] = k
    d.vals[#d.vals + 1] = v
  end
  return d
end

function krt.dict_get(d, k)
  local p = dict_pos(d, k)
  if not p then return krt.NONE end
  return d.vals[p]
end

local function dict_key(k)
  if type(k) ~= "string" then
    krt.fail("TYPE_MISMATCH_ERROR", "dict key must be str, found " .. krt.typeof(k))
  end
  return k
end

function krt.dict_add(d, k, v)
  krt.dict_set(d, dict_key(k), v)
  return krt.NONE
end

function krt.dict_take(d, k)
  return krt.dict_get(d, dict_key(k))
end

function krt.dict_remove(d, k)
  local p = dict_pos(d, dict_key(k))
  if not p then return false end
  table.remove(d.keys, p)
  table.remove(d.vals, p)
  return true
end

function krt.dict_contains(d, k)
  return dict_pos(d, dict_key(k)) ~= nil
end

function krt.dict_merge(d, other)
  for i = 1, #other.keys do
    krt.dict_set(d, other.keys[i], other.vals[i])
  end
  return krt.NONE
end

-- ---------- сравнение значений неизвестного типа ----------

local function order_pair(a, b)
  if type(a) ~= type(b) then
    krt.fail("TYPE_MISMATCH_ERROR",
      "expected comparable operands, found " .. krt.typeof(a) .. " and " .. krt.typeof(b))
  end
  if type(a) ~= "number" and type(a) ~= "string" then
    krt.fail("TYPE_MISMATCH_ERROR", "expected flint or str, found " .. krt.typeof(a))
  end
  return a, b
end

function krt.lt(a, b) local x, y = order_pair(a, b); return x < y end
function krt.le(a, b) local x, y = order_pair(a, b); return x <= y end
function krt.gt(a, b) local x, y = order_pair(a, b); return x > y end
function krt.ge(a, b) local x, y = order_pair(a, b); return x >= y end

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
