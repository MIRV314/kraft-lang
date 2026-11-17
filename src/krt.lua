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

local stdin_pos = 0

function krt.input(prompt)
  if prompt and prompt ~= "" then
    io.write(prompt)
    io.stdout:flush()
  end
  stdin_pos = stdin_pos + 1
  local line = krt.STDIN and krt.STDIN[stdin_pos]
  if line ~= nil then return line end
  line = io.read("*l")
  if line == nil then return "" end
  return line
end

-- ---------- истинность ----------

function krt.truthy(v)
  return v ~= nil and v ~= false and v ~= krt.NONE
end

-- ---------- арифметика с семантикой Python ----------

function krt.fail(cat, msg)
  local line, col
  local level = 2
  while true do
    local info = debug.getinfo(level, "l")
    if not info then break end
    local p = krt.LINE_MAP and krt.LINE_MAP[info.currentline]
    if p then
      line, col = p[1], p[2]
      break
    end
    level = level + 1
  end
  error({ kraft_runtime = true, cat = cat, msg = msg, line = line, col = col }, 0)
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

-- ---------- числа ----------

function krt.num_abs(n)
  return math.abs(krt.as_flint(n))
end

function krt.num_round(n)
  n = krt.as_flint(n)
  if n >= 0 then return math.floor(n + 0.5) end
  return math.ceil(n - 0.5)
end

function krt.num_floor(n)
  return math.floor(krt.as_flint(n))
end

function krt.num_ceil(n)
  return math.ceil(krt.as_flint(n))
end

function krt.num_sqrt(n)
  n = krt.as_flint(n)
  if n < 0 then
    krt.fail("VALUE_ERROR", "sqrt of negative number")
  end
  return math.sqrt(n)
end

local function extrema(args, count, want_max)
  local m
  if count == 1 and krt.is_list(args[1]) then
    local xs = args[1]
    if #xs == 0 then krt.fail("VALUE_ERROR", "min/max of empty list") end
    m = krt.as_flint(xs[1])
    for i = 2, #xs do
      local v = krt.as_flint(xs[i])
      if want_max then
        if v > m then m = v end
      else
        if v < m then m = v end
      end
    end
    return m
  end
  if count == 0 then krt.fail("VALUE_ERROR", "min/max needs a value") end
  m = krt.as_flint(args[1])
  for i = 2, count do
    local v = krt.as_flint(args[i])
    if want_max then
      if v > m then m = v end
    else
      if v < m then m = v end
    end
  end
  return m
end

function krt.num_min(...)
  return extrema({...}, select('#', ...), false)
end

function krt.num_max(...)
  return extrema({...}, select('#', ...), true)
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

-- flint(x): число как есть, bool → 1/0, str → разбор (мусор — VALUE_ERROR).
function krt.to_flint(v)
  if type(v) == "number" then return v end
  if type(v) == "boolean" then return v and 1 or 0 end
  if type(v) == "string" then
    local n = tonumber(v)
    if n == nil then
      krt.fail("VALUE_ERROR", "cannot convert str to flint: " .. v)
    end
    return n
  end
  krt.fail("TYPE_MISMATCH_ERROR",
    "cannot convert " .. krt.typeof(v) .. " to flint")
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
  return #krt.utf8_chars(s)
end

-- ---------- строки: индексы, срезы, методы ----------

-- Кэш символов по значению строки. Строки в Lua неизменяемы, поэтому
-- результат зависит только от неё. Слабые ключи: память освобождается,
-- когда строка больше нигде не нужна. Без кэша len(s) и s[i] в цикле
-- дают O(n^2), что делает компилятор на самом Kraft слишком медленным.
local CHARS_CACHE = setmetatable({}, { __mode = "k" })

function krt.utf8_chars(s)
  local cached = CHARS_CACHE[s]
  if cached ~= nil then return cached end
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
  CHARS_CACHE[s] = out
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

function krt.str_part(s, sep, maxsplit)
  if maxsplit == nil then maxsplit = -1 end
  maxsplit = math.floor(maxsplit)
  local out = krt.list({})
  if sep == nil then
    local chars = krt.utf8_chars(s)
    local n = #chars
    local i = 1
    local splits = 0
    while i <= n do
      while i <= n and chars[i]:match("%s") do i = i + 1 end
      if i > n then break end
      if maxsplit >= 0 and splits >= maxsplit then
        out[#out + 1] = table.concat(chars, "", i, n)
        return out
      end
      local start = i
      while i <= n and not chars[i]:match("%s") do i = i + 1 end
      out[#out + 1] = table.concat(chars, "", start, i - 1)
      splits = splits + 1
    end
    return out
  end
  if sep == "" then krt.fail("VALUE_ERROR", "empty separator") end
  local start = 1
  local splits = 0
  while maxsplit < 0 or splits < maxsplit do
    local a, b = s:find(sep, start, true)
    if not a then break end
    out[#out + 1] = s:sub(start, a - 1)
    start = b + 1
    splits = splits + 1
  end
  out[#out + 1] = s:sub(start)
  return out
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

local function trim_set(chars)
  local set = {}
  local cs = krt.utf8_chars(chars)
  for i = 1, #cs do set[cs[i]] = true end
  return set
end

function krt.str_trim(s, chars)
  if chars == nil then
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
  end
  local set = trim_set(chars)
  local cs = krt.utf8_chars(s)
  local a, b = 1, #cs
  while a <= b and set[cs[a]] do a = a + 1 end
  while b >= a and set[cs[b]] do b = b - 1 end
  return table.concat(cs, "", a, b)
end

function krt.str_triml(s, chars)
  if chars == nil then
    return (s:gsub("^%s+", ""))
  end
  local set = trim_set(chars)
  local cs = krt.utf8_chars(s)
  local a, b = 1, #cs
  while a <= b and set[cs[a]] do a = a + 1 end
  return table.concat(cs, "", a, b)
end

function krt.str_trimr(s, chars)
  if chars == nil then
    return (s:gsub("%s+$", ""))
  end
  local set = trim_set(chars)
  local cs = krt.utf8_chars(s)
  local a, b = 1, #cs
  while b >= a and set[cs[b]] do b = b - 1 end
  return table.concat(cs, "", a, b)
end

function krt.str_up(s)
  return string.upper(s)
end

function krt.str_low(s)
  return string.lower(s)
end

function krt.str_title(s)
  local chars = krt.utf8_chars(s)
  local out = {}
  local in_word = false
  for i = 1, #chars do
    local c = chars[i]
    if c:match("%w") then
      if in_word then
        out[#out + 1] = string.lower(c)
      else
        out[#out + 1] = string.upper(c)
      end
      in_word = true
    else
      out[#out + 1] = c
      in_word = false
    end
  end
  return table.concat(out)
end

function krt.str_remove(s, sub, count)
  if sub == "" then return s end
  if count == nil then count = -1 end
  count = math.floor(count)
  if count == 0 then return s end
  local out = {}
  local i = 1
  local removed = 0
  while count < 0 or removed < count do
    local a, b = s:find(sub, i, true)
    if not a then break end
    out[#out + 1] = s:sub(i, a - 1)
    i = b + 1
    removed = removed + 1
  end
  out[#out + 1] = s:sub(i)
  return table.concat(out)
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

-- Запись по индексу значения внутреннего типа any: только список.
function krt.index_set(v, i, x)
  if krt.is_list(v) then return krt.list_replace(v, i, x) end
  if type(v) == "string" then
    krt.fail("TYPE_ERROR", "str is immutable")
  end
  krt.fail("TYPE_MISMATCH_ERROR", "expected list, found " .. krt.typeof(v))
end

function krt.slice(v, from, to, step)
  if krt.is_list(v) then return krt.list_slice(v, from, to, step) end
  if type(v) == "string" then return krt.str_slice(v, from, to, step) end
  krt.fail("TYPE_MISMATCH_ERROR", "expected list or str, found " .. krt.typeof(v))
end

function krt.list_add(xs, a, b)
  if b == nil then
    xs[#xs + 1] = a
    return krt.NONE
  end
  local n = #xs
  local i = math.floor(krt.as_flint(a))
  if i < 0 then i = i + n end
  if i < 0 then i = 0 end
  if i > n then i = n end
  table.insert(xs, i + 1, b)
  return krt.NONE
end

function krt.list_del(xs, i)
  local n = #xs
  if i == nil then
    if n == 0 then
      krt.fail("VALUE_ERROR", "del from empty list")
    end
    table.remove(xs, n)
    return krt.NONE
  end
  i = math.floor(i)
  if i < 0 then i = i + n end
  if i < 0 or i >= n then
    krt.fail("VALUE_ERROR", "list index out of range: " .. tostring(math.floor(i)))
  end
  table.remove(xs, i + 1)
  return krt.NONE
end

function krt.list_remove(xs, v, count)
  if count == nil then count = -1 end
  count = math.floor(krt.as_flint(count))
  local removed = 0
  local i = 1
  while i <= #xs do
    if xs[i] == v and (count < 0 or removed < count) then
      table.remove(xs, i)
      removed = removed + 1
    else
      i = i + 1
    end
  end
  return removed > 0
end

function krt.list_replace_value(xs, a, b)
  for i = 1, #xs do
    if xs[i] == a then
      xs[i] = b
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
  local out = krt.dict()
  for i = 1, #d.keys do
    krt.dict_set(out, d.keys[i], d.vals[i])
  end
  for i = 1, #other.keys do
    krt.dict_set(out, other.keys[i], other.vals[i])
  end
  return out
end

-- ---------- коллекции: сводки и копии ----------

function krt.coll_sum(xs)
  local total = 0
  for i = 1, #xs do
    total = total + krt.as_flint(xs[i])
  end
  return total
end

function krt.coll_avg(xs)
  local n = #xs
  if n == 0 then krt.fail("VALUE_ERROR", "avg of empty list") end
  return krt.coll_sum(xs) / n
end

function krt.coll_keys(d)
  local out = krt.list({})
  for i = 1, #d.keys do out[i] = d.keys[i] end
  return out
end

function krt.coll_values(d)
  local out = krt.list({})
  for i = 1, #d.vals do out[i] = d.vals[i] end
  return out
end

function krt.coll_upk(coll)
  local out = {}
  if krt.is_dict(coll) then
    for i = 1, #coll.keys do
      out[#out + 1] = coll.keys[i] .. ": " .. krt.tostr_inner(coll.vals[i])
    end
    return table.concat(out, ", ")
  end
  if krt.is_list(coll) then
    for i = 1, #coll do out[#out + 1] = krt.tostr_inner(coll[i]) end
    return table.concat(out, ", ")
  end
  krt.fail("TYPE_MISMATCH_ERROR", "expected list or dict, found " .. krt.typeof(coll))
end

function krt.coll_sort(xs)
  local out = krt.list({})
  for i = 1, #xs do out[i] = krt.as_flint(xs[i]) end
  table.sort(out)
  return out
end

function krt.coll_reverse(xs)
  local out = krt.list({})
  local n = #xs
  for i = 1, n do out[i] = xs[n - i + 1] end
  return out
end

function krt.coll_clear(coll)
  if krt.is_list(coll) then
    for i = #coll, 1, -1 do table.remove(coll, i) end
    return krt.NONE
  end
  if krt.is_dict(coll) then
    for i = #coll.keys, 1, -1 do
      table.remove(coll.keys, i)
      table.remove(coll.vals, i)
    end
    return krt.NONE
  end
  krt.fail("TYPE_MISMATCH_ERROR", "expected list or dict, found " .. krt.typeof(coll))
end

function krt.coll_map(xs, f)
  local out = krt.list({})
  for i = 1, #xs do out[i] = f(xs[i]) end
  return out
end

function krt.coll_filter(xs, f)
  local out = krt.list({})
  for i = 1, #xs do
    local v = xs[i]
    if krt.truthy(f(v)) then out[#out + 1] = v end
  end
  return out
end

function krt.coll_reduce(xs, f, start)
  local acc = start
  for i = 1, #xs do acc = f(acc, xs[i]) end
  return acc
end

-- ---------- assert и expect ----------

function krt.do_assert(cond, msg)
  if not krt.truthy(cond) then
    krt.fail("ASSERT_ERROR", msg)
  end
  return krt.NONE
end

local EXPECT_MT = { __kraft = "expect" }

function krt.expect_new(v)
  return setmetatable({ value = v }, EXPECT_MT)
end

local function deep_eq(a, b)
  if a == b then return true end
  if krt.is_list(a) and krt.is_list(b) then
    if #a ~= #b then return false end
    for i = 1, #a do
      if not deep_eq(a[i], b[i]) then return false end
    end
    return true
  end
  if krt.is_dict(a) and krt.is_dict(b) then
    if #a.keys ~= #b.keys then return false end
    for i = 1, #a.keys do
      local p = dict_pos(b, a.keys[i])
      if not p then return false end
      if not deep_eq(a.vals[i], b.vals[p]) then return false end
    end
    return true
  end
  return false
end

function krt.expect_equals(e, x)
  if not deep_eq(e.value, x) then
    krt.fail("EXPECT_ERROR", "expected equals " .. krt.tostr_inner(x) ..
      ", found " .. krt.tostr_inner(e.value))
  end
  return krt.NONE
end

function krt.expect_true(e)
  if e.value ~= true then
    krt.fail("EXPECT_ERROR", "expected TRUE, found " .. krt.tostr_inner(e.value))
  end
  return krt.NONE
end

function krt.expect_false(e)
  if e.value ~= false then
    krt.fail("EXPECT_ERROR", "expected FALSE, found " .. krt.tostr_inner(e.value))
  end
  return krt.NONE
end

function krt.expect_none(e)
  if e.value ~= krt.NONE then
    krt.fail("EXPECT_ERROR", "expected NONE, found " .. krt.tostr_inner(e.value))
  end
  return krt.NONE
end

function krt.expect_contains(e, x)
  local v = e.value
  local ok = false
  if type(v) == "string" then
    ok = krt.str_contains(v, krt.as_str(x))
  elseif krt.is_list(v) then
    ok = krt.list_contains(v, x)
  elseif krt.is_dict(v) then
    ok = krt.dict_contains(v, krt.as_str(x))
  else
    krt.fail("TYPE_MISMATCH_ERROR", "contains: expected str, list or dict, found " .. krt.typeof(v))
  end
  if not ok then
    krt.fail("EXPECT_ERROR", "expected " .. krt.tostr_inner(v) ..
      " to contain " .. krt.tostr_inner(x))
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

-- ---------- файлы ----------

function krt.read_file(path)
  local f = io.open(path, "rb")
  if not f then
    krt.fail("FILE_ERROR", "cannot read file: " .. path)
  end
  local data = f:read("*a")
  f:close()
  return data
end

function krt.write_file(path, text)
  local f = io.open(path, "wb")
  if not f then
    krt.fail("FILE_ERROR", "cannot write file: " .. path)
  end
  f:write(text)
  f:close()
  return true
end

function krt.file_exists(path)
  local f = io.open(path, "rb")
  if not f then return false end
  f:close()
  return true
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

function krt.system(cmd)
  local st = os.execute(cmd)
  if st == nil then return -1 end
  local sig = st % 256
  if sig ~= 0 then return 128 + sig end
  return math.floor(st / 256)
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

  io.stdout:flush()

  local red, yellow, reset = "", "", ""
  if krt.is_tty() then
    red, yellow, reset = "\27[31m", "\27[33m", "\27[0m"
  end

  if type(err) == "table" and err.kraft_runtime then
    if err.line then
      local src = krt.SOURCE_LINES and krt.SOURCE_LINES[err.line] or ""
      local num = string.format("%5d | ", err.line)
      local col = err.col or 1
      io.stderr:write(red .. err.cat .. reset .. ": " ..
        (krt.SOURCE_PATH or "?") .. ":" .. err.line .. "\n")
      io.stderr:write(num .. src .. "\n")
      io.stderr:write(string.rep(" ", #num + col - 1) .. "^ " ..
        red .. err.msg .. reset .. "\n")
    else
      io.stderr:write(red .. err.cat .. reset .. ": " .. err.msg .. "\n")
    end
  else
    io.stderr:write(red .. "RUNTIME_ERROR" .. reset .. ": " .. tostring(err) .. "\n")
  end
  os.exit(1)
end

return krt
