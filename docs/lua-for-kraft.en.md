# Lua in 10 Minutes — for Reading Generated Code

> Russian original: [lua-for-kraft.md](lua-for-kraft.md). The Russian version is authoritative.

Kraft compiles to Lua. It is easier to read than it seems: there are only a few
constructs. This file is enough to understand `--emit-lua`.

## 1. Variables

```lua
local x = 5        -- local variable
x = x + 1          -- assignment
```

`local` means "declare here". In generated code, variable names are replaced
with `v_1`, `v_2`, … in order of declaration (Cyrillic is not allowed in Lua).

## 2. Numbers, Strings, Booleans

```lua
local n = 3.5
local s = "привет"
local b = true
local nothing = nil
```

Lua has one numeric type — like `flint`. Strings are byte strings.

## 3. Conditionals and Loops

```lua
if x > 0 then
  ...
elseif x < 0 then
  ...
else
  ...
end

while x < 10 do
  x = x + 1
end

for i = 0, 4 do          -- 0,1,2,3,4
  ...
end
```

## 4. Tables Are Both Lists and Dictionaries

```lua
local xs = {10, 20, 30}          -- indices start at 1
local d = { name = "Kraft" }     -- by key
print(xs[1])                     -- 10
print(d.name)                    -- Kraft
```

**Important:** indices in Lua start at **1**, while in Kraft they start at 0.
The code generator adds one itself; in generated code you will see `xs[i + 1]`.

## 5. Functions

```lua
local function add(a, b)
  return a + b
end
```

Functions are values and can be passed around.

## 6. Strings

```lua
local s = "a" .. "b"       -- concatenation
local n = #s               -- length in bytes
local up = s:upper()       -- method via colon
print(string.format("%d", 42))
```

Kraft has no concatenation — instead it has `{}` interpolation, which turns
into `..` in generated code.

## 7. nil and false

In Lua, only `nil` and `false` are falsey. Zero and the empty string are truthy.
In Kraft, falsehood is `NONE` and `FALSE`, so `NONE` is a separate table
`krt.NONE`, not `nil`.

## 8. Errors

```lua
local ok, err = pcall(function()
  error("что-то сломалось")
end)
```

`pcall` catches an error. That is how `krt.run` prints Kraft errors instead of
Lua tracebacks.

## 9. Metatables (One Line)

```lua
setmetatable(t, mt)
```

This is a way to attach a "type" to a table. That is how `krt.list` and
`krt.dict` differ from each other, even though both are tables.

## 10. What a Kraft Program Looks Like

```kraft
str name = "Kraft"
show(привет, {name}!)
```

turns roughly into:

```lua
local v_1 = "Kraft"
krt.show("привет, " .. krt.tostr(v_1) .. "!")
```

Everything else is details. If you understand these ten points, you understand
the output of `--emit-lua`.
