-- Kraft runtime. Встраивается в сгенерированный Lua целиком.
-- Никаких зависимостей, кроме LuaJIT (Lua 5.1).

local krt = {}

-- NONE — отдельное значение, а не nil: nil нельзя положить в список/словарь.
krt.NONE = setmetatable({}, { __tostring = function() return "NONE" end })

-- Встроенная константа PI: число π, доступная в Kraft как `PI`.
krt.PI = math.pi

local LIST_MT = { __kraft = "list" }
local FROZ_MT = { __kraft = "list" }
local DICT_MT = { __kraft = "dict" }
local MODEL_MT = { __kraft = "model" }
local RANGE_MT = { __kraft = "range" }

function krt.list(t) return setmetatable(t or {}, LIST_MT) end
function krt.froz(t, spec)
  local v = t or {}
  v.__kraft_froz = true
  v.__kraft_type = spec
  return setmetatable(v, FROZ_MT)
end
function krt.dict() return setmetatable({ keys = {}, vals = {} }, DICT_MT) end

local function kraft_kind(v)
  if type(v) ~= "table" then return nil end
  local mt = getmetatable(v)
  return mt and mt.__kraft or nil
end

function krt.is_list(v) return kraft_kind(v) == "list" end
function krt.is_froz(v) return type(v) == "table" and getmetatable(v) == FROZ_MT end
function krt.is_dict(v) return kraft_kind(v) == "dict" end
function krt.is_range(v) return kraft_kind(v) == "range" end
function krt.is_model_table(v)
  return type(v) == "table" and getmetatable(v) == MODEL_MT
end
function krt.is_model(v, name)
  return krt.is_model_table(v) and v.__kraft_model == name
end

-- ---------- диапазоны и in ----------

function krt.range_new(from, to, step, kind)
  if type(from) ~= "number" or type(to) ~= "number" or type(step) ~= "number" then
    krt.fail("TYPE_MISMATCH_ERROR", "expected flint range bounds and step")
  end
  if step == 0 then krt.fail("VALUE_ERROR", "range step cannot be zero") end
  return setmetatable({ from = from, to = to, step = step, kind = kind }, RANGE_MT)
end

function krt.in_range(v, r)
  if not krt.is_range(r) then krt.fail("TYPE_ERROR", "expected range, found " .. krt.typeof(r)) end
  if type(v) ~= "number" then
    krt.fail("TYPE_MISMATCH_ERROR", "expected flint, found " .. krt.typeof(v))
  end
  if v < r.from or v >= r.to then return false end
  if r.kind == "int" then return true end
  local q = (v - r.from) / r.step
  return math.abs(q - math.floor(q + 0.5)) < 1e-9
end

function krt.in_list(v, xs)
  for i = 1, #xs do
    if xs[i] == v then return true end
  end
  return false
end

function krt.in_dict_keys(k, d)
  for i = 1, #d.keys do
    if d.keys[i] == k then return true end
  end
  return false
end

function krt.in_str(part, s)
  return string.find(s, part, 1, true) ~= nil
end

-- ---------- модели ----------

krt.MODELS = {}

function krt.model_define(name, model_fields, field_types, consts, init_fields, params, param_types)
  krt.MODELS[name] = {
    name = name,
    model_fields = model_fields,
    field_types = field_types,
    consts = consts,
    init_fields = init_fields,
    params = params,
    param_types = param_types,
    values = {},
    methods = {},
    construct = nil,
  }
end

function krt.model_set_value(name, field, value)
  local m = krt.MODELS[name]
  if not m then krt.fail("NAME_ERROR", "unknown model '" .. name .. "'") end
  m.values[field] = value
end

function krt.model_construct(name, fn)
  local m = krt.MODELS[name]
  if not m then krt.fail("NAME_ERROR", "unknown model '" .. name .. "'") end
  m.construct = fn
end

function krt.model_method(name, method, fn)
  local m = krt.MODELS[name]
  if not m then krt.fail("NAME_ERROR", "unknown model '" .. name .. "'") end
  m.methods[method] = fn
end

local function check_value(ty, v, where)
  local got = krt.typeof(v)
  if ty == "any" or ty == "NONE" then return v end
  if ty == "str" or ty == "flint" or ty == "bool" or ty == "list" or ty == "dict" then
    if got ~= ty then
      krt.fail("TYPE_MISMATCH_ERROR", where .. ": expected " .. ty .. ", found " .. got)
    end
    return v
  end
  if got ~= ty then
    krt.fail("TYPE_MISMATCH_ERROR", where .. ": expected " .. ty .. ", found " .. got)
  end
  return v
end

function krt.as_model(v, name)
  if not krt.is_model(v, name) then
    krt.fail("TYPE_MISMATCH_ERROR", "expected " .. name .. ", found " .. krt.typeof(v))
  end
  return v
end

function krt.model_new(name, ...)
  local m = krt.MODELS[name]
  if not m then krt.fail("NAME_ERROR", "unknown model '" .. name .. "'") end
  local n = select("#", ...)
  local want = #m.params
  if n ~= want then
    krt.fail("ARGCOUNT_ERROR", "expected " .. want .. " argument(s) to '" .. name .. "', got " .. n)
  end
  local args = { ... }
  for i = 1, want do
    check_value(m.param_types[m.params[i]], args[i], name .. "(" .. m.params[i] .. ")")
  end
  local obj = setmetatable({ __kraft_model = name }, MODEL_MT)
  m.construct(obj, unpack(args, 1, want))
  return obj
end

function krt.model_init(name, named)
  local m = krt.MODELS[name]
  if not m then krt.fail("NAME_ERROR", "unknown model '" .. name .. "'") end
  local args = {}
  local seen = {}
  for i = 1, #m.params do
    local p = m.params[i]
    local v = named[p]
    if v == nil then
      krt.fail("ARGCOUNT_ERROR", "missing init argument '" .. p .. "' for '" .. name .. "'")
    end
    seen[p] = true
    args[i] = check_value(m.param_types[p], v, name .. ".init(" .. p .. ")")
  end
  local obj = krt.model_new(name, unpack(args, 1, #m.params))
  for k, v in pairs(named) do
    if not seen[k] then
      if m.model_fields[k] then
        krt.fail("CONST_ERROR", "model field '" .. k .. "' is read-only")
      elseif m.consts[k] then
        krt.fail("CONST_ERROR", "constant '" .. k .. "' is read-only")
      elseif m.init_fields[k] then
        obj[k] = check_value(m.field_types[k], v, name .. ".init(" .. k .. ")")
      else
        krt.fail("NAME_ERROR", "unknown init field '" .. k .. "' of '" .. name .. "'")
      end
    end
  end
  return obj
end

function krt.model_get(obj, field)
  if not krt.is_model_table(obj) then
    krt.fail("TYPE_MISMATCH_ERROR", "expected a model instance, found " .. krt.typeof(obj))
  end
  local m = krt.MODELS[obj.__kraft_model]
  if not m then krt.fail("NAME_ERROR", "unknown model '" .. tostring(obj.__kraft_model) .. "'") end
  local v = obj[field]
  if v ~= nil then return v end
  v = m.values[field]
  if v ~= nil then return v end
  krt.fail("NAME_ERROR", "unknown field '" .. field .. "' of '" .. m.name .. "'")
end

function krt.model_set(obj, field, value)
  if not krt.is_model_table(obj) then
    krt.fail("TYPE_MISMATCH_ERROR", "expected a model instance, found " .. krt.typeof(obj))
  end
  local m = krt.MODELS[obj.__kraft_model]
  if not m then krt.fail("NAME_ERROR", "unknown model '" .. tostring(obj.__kraft_model) .. "'") end
  if m.model_fields[field] then
    krt.fail("CONST_ERROR", "model field '" .. field .. "' is read-only")
  end
  if m.consts[field] then
    krt.fail("CONST_ERROR", "constant '" .. field .. "' is read-only")
  end
  if m.field_types[field] == nil then
    krt.fail("NAME_ERROR", "unknown field '" .. field .. "' of '" .. m.name .. "'")
  end
  obj[field] = check_value(m.field_types[field], value, m.name .. "." .. field)
  return value
end

function krt.model_create_field(obj, field, value, is_const, ty)
  if not krt.is_model_table(obj) then
    krt.fail("TYPE_MISMATCH_ERROR", "expected a model instance, found " .. krt.typeof(obj))
  end
  obj[field] = check_value(ty, value, obj.__kraft_model .. "." .. field)
  return value
end

function krt.model_call(obj, method, ...)
  if not krt.is_model_table(obj) then
    krt.fail("TYPE_MISMATCH_ERROR", "expected a model instance, found " .. krt.typeof(obj))
  end
  local m = krt.MODELS[obj.__kraft_model]
  if not m then krt.fail("NAME_ERROR", "unknown model '" .. tostring(obj.__kraft_model) .. "'") end
  local fn = m.methods[method]
  if not fn then
    krt.fail("NAME_ERROR", "unknown method '" .. method .. "' of '" .. m.name .. "'")
  end
  return fn(obj, ...)
end

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
    if krt.is_model_table(v) then
      krt.fail("TYPE_MISMATCH_ERROR", "cannot print a model instance; use its fields or methods")
    end
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

-- Значение дробного range: целые шаги печатаются с .0, остальные как есть.
function krt.tostr_range_flint(v)
  if type(v) == "number" and is_integral(v) then
    return string.format("%.1f", v)
  end
  return krt.tostr(v)
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

-- Новая модель: TRUE — истина, FALSE и NONE — ложь, всё остальное — ошибка.
-- Старая krt.truthy выше остаётся для замороженного v0.1.
function krt.truthy_strict(v)
  if v == true then return true end
  if v == false or v == nil or v == krt.NONE then return false end
  krt.fail("TYPE_ERROR", "condition must be bool (TRUE, FALSE or NONE), found " .. krt.typeof(v))
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

function krt.num_factorial(n)
  n = krt.as_flint(n)
  if n <= 1 then return 1 end
  local r = 1
  for i = 2, n do r = r * i end
  return r
end

function krt.num_fib(n)
  n = krt.as_flint(n)
  if n <= 1 then return n end
  local a, b = 0, 1
  for i = 2, n do a, b = b, a + b end
  return b
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
  if type(v) == "string" then
    local n = tonumber(v)
    if n ~= nil then return n end
    krt.fail("TYPE_MISMATCH_ERROR", "expected flint, found str: " .. v)
  end
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

-- flint(x): число как есть, bool → 1/0, str → разбор (мусор — TYPE_MISMATCH_ERROR).
function krt.to_flint(v)
  if type(v) == "number" then return v end
  if type(v) == "boolean" then return v and 1 or 0 end
  if type(v) == "string" then
    local n = tonumber(v)
    if n == nil then
      krt.fail("TYPE_MISMATCH_ERROR", "expected flint, found str: " .. v)
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
    if krt.is_model_table(v) then return v.__kraft_model end
    if krt.is_range(v) then return "range" end
    if krt.is_list(v) then return "list" end
    if krt.is_dict(v) then return "dict" end
    return "dict"
  end
  return t
end

-- ---------- типизированные коллекции ----------

-- Спецификация приходит от компилятора в каноническом виде:
--   list[flint, str], froz[bool], dict[str], dict[flint|list].
-- Ключ словаря — str или flint; значение — любой тип.
local BASE_TYPES = { str = true, flint = true, bool = true }

local function split_args(s)
  local out = {}
  local start = 1
  local depth = 0
  for i = 1, #s do
    local c = s:sub(i, i)
    if c == "[" then depth = depth + 1 end
    if c == "]" then depth = depth - 1 end
    if c == "," and depth == 0 then
      out[#out + 1] = s:sub(start, i - 1)
      start = i + 1
    end
  end
  out[#out + 1] = s:sub(start)
  for i = 1, #out do
    out[i] = out[i]:gsub("^%s+", ""):gsub("%s+$", "")
  end
  return out
end

local function spec_info(spec)
  local name, inner = spec:match("^([%a_]+)%[(.*)%]$")
  if not name then return spec, nil end
  return name, split_args(inner)
end

local function type_error(where, expected, v)
  krt.fail("TYPE_MISMATCH_ERROR",
    where .. ": expected " .. expected .. ", found " .. krt.typeof(v))
end

local function check_base(t, v, where)
  if krt.typeof(v) ~= t then type_error(where, t, v) end
end

local function one_of(args, v)
  local got = krt.typeof(v)
  for i = 1, #args do
    local want = spec_info(args[i])
    if want == "any" or want == got then return true end
  end
  return false
end

local function expected_text(args)
  return table.concat(args, " or ")
end

function krt.check_type(spec, v, where)
  if not spec or spec == "any" then return v end
  local name, args = spec_info(spec)
  if name == "list" or name == "froz" then
    if name == "froz" then
      if not krt.is_froz(v) then type_error(where, spec, v) end
    elseif not krt.is_list(v) or krt.is_froz(v) then
      type_error(where, spec, v)
    end
    if args then
      for i = 1, #v do
        if not one_of(args, v[i]) then
          type_error(where .. "[" .. (i - 1) .. "]", expected_text(args), v[i])
        end
      end
    end
    return v
  end
  if name == "dict" then
    if not krt.is_dict(v) then type_error(where, spec, v) end
    if args then
      for i = 1, #v.keys do
        if args[1] then check_base(args[1], v.keys[i], where .. ".key") end
        if args[2] and BASE_TYPES[args[2]] then
          check_base(args[2], v.vals[i], where .. "[" .. krt.tostr(v.keys[i]) .. "]")
        end
      end
    end
    return v
  end
  if BASE_TYPES[name] then
    check_base(name, v, where)
    return v
  end
  if not krt.is_model(v, name) then type_error(where, name, v) end
  return v
end

function krt.typed_list(spec, values)
  local v = krt.list(values or {})
  v.__kraft_type = spec
  return krt.check_type(spec, v, "list declaration")
end

function krt.typed_froz(spec, values)
  return krt.check_type(spec, krt.froz(values or {}, spec), "froz declaration")
end

function krt.typed_dict(spec, values)
  local v = values or krt.dict()
  v.__kraft_type = spec
  return krt.check_type(spec, v, "dict declaration")
end

function krt.typed_attach(v, spec)
  v.__kraft_type = spec
  return krt.check_type(spec, v, "declaration")
end

local function list_args(xs)
  if type(xs) ~= "table" or not xs.__kraft_type then return nil end
  local name, args = spec_info(xs.__kraft_type)
  if name == "list" or name == "froz" then return args end
  return nil
end

local function dict_args(d)
  if type(d) ~= "table" or not d.__kraft_type then return nil end
  local name, args = spec_info(d.__kraft_type)
  if name == "dict" then return args end
  return nil
end

local function check_elem(xs, v, where)
  local args = list_args(xs)
  if not args then return end
  if not one_of(args, v) then type_error(where, expected_text(args), v) end
end

local function ensure_mutable(xs)
  if krt.is_froz(xs) then
    krt.fail("CONST_ERROR", "froz collection is read-only")
  end
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
  if not krt.is_list(v) or krt.is_froz(v) then
    krt.fail("TYPE_MISMATCH_ERROR", "expected list, found " .. krt.typeof(v))
  end
  return v
end

function krt.as_froz(v)
  if not krt.is_froz(v) then
    krt.fail("TYPE_MISMATCH_ERROR", "expected froz, found " .. krt.typeof(v))
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

  local out
  if krt.is_froz(xs) then
    out = krt.froz({}, xs.__kraft_type)
  else
    out = krt.list({})
    if xs.__kraft_type then out.__kraft_type = xs.__kraft_type end
  end
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
  ensure_mutable(xs)
  if b == nil then
    check_elem(xs, a, "list.add")
    xs[#xs + 1] = a
    return krt.NONE
  end
  local n = #xs
  local i = math.floor(krt.as_flint(a))
  if i < 0 then i = i + n end
  if i < 0 then i = 0 end
  if i > n then i = n end
  check_elem(xs, b, "list.add")
  table.insert(xs, i + 1, b)
  return krt.NONE
end

function krt.list_del(xs, i)
  ensure_mutable(xs)
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
  ensure_mutable(xs)
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
  ensure_mutable(xs)
  check_elem(xs, b, "list.replace")
  for i = 1, #xs do
    if xs[i] == a then
      xs[i] = b
      return true
    end
  end
  return false
end

function krt.list_replace(xs, i, v)
  ensure_mutable(xs)
  check_elem(xs, v, "list index assignment")
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
  local args = dict_args(d)
  if args then
    if args[1] then check_base(args[1], k, "dict key") end
    if args[2] and BASE_TYPES[args[2]] then
      check_base(args[2], v, "dict value")
    end
  end
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
  local tk = type(k)
  if tk ~= "string" and tk ~= "number" then
    krt.fail("TYPE_MISMATCH_ERROR", "dict key must be str or flint, found " .. krt.typeof(k))
  end
  return k
end

function krt.dict_add(d, k, v)
  ensure_mutable(d)
  krt.dict_set(d, dict_key(k), v)
  return krt.NONE
end

function krt.dict_take(d, k)
  return krt.dict_get(d, dict_key(k))
end

function krt.dict_remove(d, k)
  ensure_mutable(d)
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
  ensure_mutable(coll)
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

function krt.do_assert_strict(cond, msg)
  if not krt.truthy_strict(cond) then
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
  local embedded = krt.EMBEDDED_SOURCES[path]
  if embedded then return embedded end
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
  if krt.EMBEDDED_SOURCES[path] then return true end
  local f = io.open(path, "rb")
  if not f then return false end
  f:close()
  return true
end

-- Встроенные в дистрибутив исходники (stdlib). Обычная сборка оставляет
-- таблицу пустой и читает файлы с диска.
krt.EMBEDDED_SOURCES = krt.EMBEDDED_SOURCES or {}

function krt.copy_file(src, dst)
  local f = io.open(src, "rb")
  if not f then return false end
  local data = f:read("*a")
  f:close()
  local o = io.open(dst, "wb")
  if not o then return false end
  o:write(data)
  o:close()
  return true
end

function krt.remove_file(path)
  local ok = os.remove(path)
  return ok == true
end

-- ---------- JSON ----------

local function json_fail(msg)
  krt.fail("VALUE_ERROR", "json: " .. msg)
end

local function json_ws(s, i)
  while i <= #s and s:sub(i, i):match("%s") do i = i + 1 end
  return i
end

local function json_utf8(cp)
  if cp < 0x80 then return string.char(cp) end
  if cp < 0x800 then
    return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
  end
  return string.char(0xE0 + math.floor(cp / 0x1000),
    0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
end

local JSON_ESCAPES = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/',
  b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }

local function json_read_string(s, i)
  if s:sub(i, i) ~= '"' then json_fail("string expected") end
  i = i + 1
  local out = {}
  while i <= #s do
    local c = s:sub(i, i)
    if c == '"' then return table.concat(out), i + 1 end
    if c == '\\' then
      i = i + 1
      local e = s:sub(i, i)
      if e == 'u' then
        local hex = s:sub(i + 1, i + 4)
        if #hex ~= 4 or not hex:match("^%x%x%x%x$") then json_fail("bad unicode escape") end
        out[#out + 1] = json_utf8(tonumber(hex, 16))
        i = i + 4
      elseif JSON_ESCAPES[e] then
        out[#out + 1] = JSON_ESCAPES[e]
      else
        json_fail("bad escape")
      end
    else
      out[#out + 1] = c
    end
    i = i + 1
  end
  json_fail("unterminated string")
end

local function json_read_value(s, i, depth)
  if depth > 64 then json_fail("too deep") end
  i = json_ws(s, i)
  local c = s:sub(i, i)
  if c == '{' then
    local d = krt.dict()
    i = json_ws(s, i + 1)
    if s:sub(i, i) == '}' then return d, i + 1 end
    while true do
      local key
      key, i = json_read_string(s, i)
      i = json_ws(s, i)
      if s:sub(i, i) ~= ':' then json_fail("':' expected") end
      local v
      v, i = json_read_value(s, i + 1, depth + 1)
      krt.dict_add(d, key, v)
      i = json_ws(s, i)
      local sep = s:sub(i, i)
      if sep == ',' then
        i = json_ws(s, i + 1)
      elseif sep == '}' then
        return d, i + 1
      else
        json_fail("',' or '}' expected")
      end
    end
  elseif c == '[' then
    local xs = {}
    i = json_ws(s, i + 1)
    if s:sub(i, i) == ']' then return krt.list(xs), i + 1 end
    while true do
      local v
      v, i = json_read_value(s, i, depth + 1)
      xs[#xs + 1] = v
      i = json_ws(s, i)
      local sep = s:sub(i, i)
      if sep == ',' then
        i = json_ws(s, i + 1)
      elseif sep == ']' then
        return krt.list(xs), i + 1
      else
        json_fail("',' or ']' expected")
      end
    end
  elseif c == '"' then
    return json_read_string(s, i)
  elseif s:sub(i, i + 3) == 'true' then
    return true, i + 4
  elseif s:sub(i, i + 4) == 'false' then
    return false, i + 5
  elseif s:sub(i, i + 3) == 'null' then
    return krt.NONE, i + 4
  end
  local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
  if num then return tonumber(num), i + #num end
  json_fail("value expected")
end

function krt.json_parse(s)
  local v, i = json_read_value(s, 1, 0)
  i = json_ws(s, i)
  if i <= #s then json_fail("trailing data") end
  if not krt.is_dict(v) then krt.fail("TYPE_ERROR", "json: top-level object expected") end
  return v
end

local function json_quote(s)
  s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
    :gsub("\r", "\\r"):gsub("\t", "\\t")
  return '"' .. s .. '"'
end

local function json_write(v, depth)
  if depth > 64 then json_fail("too deep") end
  if v == nil or v == krt.NONE then return "null" end
  local t = type(v)
  if t == "string" then return json_quote(v) end
  if t == "number" then return krt.num_to_str(v) end
  if t == "boolean" then return v and "true" or "false" end
  if krt.is_list(v) or krt.is_froz(v) then
    local out = {}
    for i = 1, #v do out[i] = json_write(v[i], depth + 1) end
    return "[" .. table.concat(out, ", ") .. "]"
  end
  if krt.is_dict(v) then
    local out = {}
    for i = 1, #v.keys do
      local k = v.keys[i]
      local ks = type(k) == "string" and json_quote(k) or krt.num_to_str(k)
      out[i] = ks .. ": " .. json_write(v.vals[i], depth + 1)
    end
    return "{" .. table.concat(out, ", ") .. "}"
  end
  krt.fail("TYPE_ERROR", "json: cannot stringify " .. krt.typeof(v))
end

function krt.json_stringify(v)
  return json_write(v, 0)
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
  -- LuaJIT returns the raw wait status as a number; some builds of Lua 5.1/5.2
  -- return true/false plus "exit"/"signal" and a code instead.
  local a, kind, code = os.execute(cmd)
  if type(a) == "number" then
    local st = a
    local sig = st % 256
    if sig ~= 0 then return 128 + sig end
    return math.floor(st / 256)
  end
  if type(code) == "number" then
    if kind == "signal" then return 128 + code end
    return code
  end
  if a == true then return 0 end
  return -1
end

function krt.is_tty()
  local ok, ffi = pcall(require, "ffi")
  if not ok then return false end
  pcall(ffi.cdef, "int isatty(int);")
  local ok2, r = pcall(function() return ffi.C.isatty(2) end)
  return ok2 and r == 1
end

-- ---------- встроенная модель Error ----------

do
  local fields = { cat = "str", msg = "str", file = "str", line = "flint", col = "flint" }
  local consts = { cat = true, msg = true, file = true, line = true, col = true }
  krt.MODELS["Error"] = {
    name = "Error",
    model_fields = {},
    field_types = fields,
    consts = consts,
    init_fields = {},
    params = {},
    param_types = {},
    values = {},
    methods = {},
    construct = nil,
  }
  krt.MODELS["Error"].methods.text = function(self)
    local where = ""
    if self.line and self.line > 0 then
      where = " (" .. self.file .. ":" .. self.line .. ":" .. self.col .. ")"
    end
    return self.cat .. ": " .. self.msg .. where
  end
end

function krt.error_new(err)
  local e = setmetatable({ __kraft_model = "Error" }, MODEL_MT)
  if type(err) == "table" and err.kraft_runtime then
    e.cat = err.cat or "RUNTIME_ERROR"
    e.msg = err.msg or ""
    e.file = err.path or err.file or krt.SOURCE_PATH or "?"
    e.line = err.line or 0
    e.col = err.col or 0
  else
    e.cat = "RUNTIME_ERROR"
    e.msg = tostring(err)
    e.file = krt.SOURCE_PATH or "?"
    e.line = 0
    e.col = 0
  end
  return e
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
