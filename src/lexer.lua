-- Лексер Kraft. Строки и шаблоны show/input режутся на части:
-- текст + выражения внутри {}.

local lexer = {}

local KEYWORDS = {}
for _, w in ipairs({
  "func", "model", "method", "construct", "if", "elif", "else", "for", "in",
  "while", "break", "continue", "return", "is", "AND", "OR", "NOT", "glob",
  "self", "try", "finally", "trigger", "panic", "init", "import_file",
  "from_file", "import_lib", "from_lib",
  "str", "flint", "bool", "list", "dict", "froz",
  "TRUE", "FALSE", "NONE",
}) do KEYWORDS[w] = true end

local TEMPLATE_FUNCS = { show = true, show_err = true, input = true }

local OPS2 = {
  ["**"] = true, ["//"] = true, ["=="] = true, ["!="] = true,
  ["<="] = true, [">="] = true,
  ["+="] = true, ["-="] = true, ["*="] = true, ["/="] = true, ["%="] = true,
}

local OPS1 = {}
for c in ("+-*/%<>=()[]{},:."):gmatch(".") do OPS1[c] = true end

local function is_name_start(c)
  local b = c:byte()
  return c:match("^[A-Za-z_]$") ~= nil or (b ~= nil and b >= 0x80)
end

local function is_name_char(c)
  local b = c:byte()
  return c:match("^[A-Za-z0-9_]$") ~= nil or (b ~= nil and b >= 0x80)
end

-- Колонка в символах UTF-8, а не в байтах.
local function char_col(line, pos)
  local n = 0
  for i = 1, pos - 1 do
    local b = line:byte(i)
    if not (b >= 0x80 and b < 0xC0) then n = n + 1 end
  end
  return n + 1
end

local ESCAPES = {
  n = "\n", t = "\t", r = "\r", e = "\27",
  ["\\"] = "\\", ["{"] = "{", ["}"] = "}", ["("] = "(", [")"] = ")",
  ['"'] = '"', ["'"] = "'",
}

-- Сканирует строку или шаблон начиная с i.
-- quoted=true  -> закрывающая кавычка quote
-- quoted=false -> закрывающая скобка )
-- Возвращает parts, позицию закрывающего символа или nil, nil, err.
local function scan_parts(line, i, lineno, quoted, quote)
  local parts, text = {}, {}

  local function flush()
    if #text > 0 then
      parts[#parts + 1] = { kind = "text", value = table.concat(text) }
      text = {}
    end
  end

  while i <= #line do
    local c = line:sub(i, i)
    if c == "\\" then
      local n = line:sub(i + 1, i + 1)
      local v = ESCAPES[n]
      if v == nil then
        return nil, nil, { msg = "unknown escape '\\" .. n .. "'", col = char_col(line, i) }
      end
      text[#text + 1] = v
      i = i + 2
    elseif c == "{" then
      flush()
      local start = i + 1
      local depth = 0
      local j = start
      while j <= #line do
        local d = line:sub(j, j)
        if d == '"' or d == "'" then
          local q = d
          j = j + 1
          while j <= #line do
            local e = line:sub(j, j)
            if e == "\\" then
              j = j + 2
            elseif e == q then
              j = j + 1
              break
            else
              j = j + 1
            end
          end
        elseif d == "{" then
          depth = depth + 1
          j = j + 1
        elseif d == "}" then
          if depth == 0 then break end
          depth = depth - 1
          j = j + 1
        else
          j = j + 1
        end
      end
      if j > #line then
        return nil, nil, { msg = "unclosed '{'", col = char_col(line, i) }
      end
      local src = line:sub(start, j - 1)
      if src:match("^%s*$") then
        return nil, nil, { msg = "empty substitution '{}'", col = char_col(line, i) }
      end
      parts[#parts + 1] = {
        kind = "expr", src = src, line = lineno, col = char_col(line, start),
      }
      i = j + 1
    elseif c == "}" then
      return nil, nil, { msg = "unexpected '}': use '\\}'", col = char_col(line, i) }
    elseif quoted and c == quote then
      flush()
      return parts, i
    elseif (not quoted) and c == ")" then
      flush()
      return parts, i
    else
      text[#text + 1] = c
      i = i + 1
    end
  end

  if quoted then
    return nil, nil, { msg = "unclosed string", col = char_col(line, i) }
  end
  return nil, nil, { msg = "unclosed show template: expected ')'", col = char_col(line, i) }
end

-- Разбирает одну строку (без отступа). Возвращает true или nil, err.
local function scan_line(line, i, lineno, tokens)
  while i <= #line do
    local c = line:sub(i, i)

    if c == " " or c == "\t" then
      i = i + 1

    elseif c == "#" then
      break

    elseif c == '"' or c == "'" then
      local parts, close, err = scan_parts(line, i + 1, lineno, true, c)
      if not parts then
        err.line = lineno
        return nil, err
      end
      tokens[#tokens + 1] = {
        type = "string", parts = parts, line = lineno, col = char_col(line, i),
      }
      i = close + 1

    elseif c:match("^[0-9]$") then
      local j = i
      while j <= #line and line:sub(j, j):match("^[0-9]$") do j = j + 1 end
      if line:sub(j, j) == "." and line:sub(j + 1, j + 1) ~= "." then
        j = j + 1
        while j <= #line and line:sub(j, j):match("^[0-9]$") do j = j + 1 end
      end
      local raw = line:sub(i, j - 1)
      tokens[#tokens + 1] = {
        type = "number", value = tonumber(raw), raw = raw,
        line = lineno, col = char_col(line, i),
      }
      i = j

    elseif is_name_start(c) then
      local j = i + 1
      while j <= #line and is_name_char(line:sub(j, j)) do j = j + 1 end
      local word = line:sub(i, j - 1)
      local col = char_col(line, i)

      if TEMPLATE_FUNCS[word] then
        local k = j
        while k <= #line and (line:sub(k, k) == " " or line:sub(k, k) == "\t") do k = k + 1 end
        if line:sub(k, k) == "(" then
          tokens[#tokens + 1] = { type = "name", value = word, line = lineno, col = col }
          tokens[#tokens + 1] = { type = "op", value = "(", line = lineno, col = char_col(line, k) }
          local parts, close, err = scan_parts(line, k + 1, lineno, false)
          if not parts then
            err.line = lineno
            return nil, err
          end
          tokens[#tokens + 1] = {
            type = "template", parts = parts, line = lineno, col = char_col(line, k + 1),
          }
          tokens[#tokens + 1] = { type = "op", value = ")", line = lineno, col = char_col(line, close) }
          i = close + 1
        else
          tokens[#tokens + 1] = { type = "name", value = word, line = lineno, col = col }
          i = j
        end
      elseif KEYWORDS[word] then
        tokens[#tokens + 1] = { type = "kw", value = word, line = lineno, col = col }
        i = j
      else
        tokens[#tokens + 1] = { type = "name", value = word, line = lineno, col = col }
        i = j
      end

    else
      local three = line:sub(i, i + 2)
      local two = line:sub(i, i + 1)
      if three == "**=" or three == "//=" then
        tokens[#tokens + 1] = { type = "op", value = three, line = lineno, col = char_col(line, i) }
        i = i + 3
      elseif OPS2[two] then
        tokens[#tokens + 1] = { type = "op", value = two, line = lineno, col = char_col(line, i) }
        i = i + 2
      elseif OPS1[c] then
        tokens[#tokens + 1] = { type = "op", value = c, line = lineno, col = char_col(line, i) }
        i = i + 1
      else
        return nil, {
          msg = "unexpected character '" .. c .. "'",
          line = lineno, col = char_col(line, i),
        }
      end
    end
  end

  return true
end

-- Токенизирует весь файл. Возвращает tokens или nil, err.
function lexer.tokenize(src, path)
  local tokens = {}
  local indent_stack = { "" }
  local lineno = 0
  local in_block = false

  local lines = {}
  for line in (src .. "\n"):gmatch("(.-)\r?\n") do lines[#lines + 1] = line end

  for _, line in ipairs(lines) do
    lineno = lineno + 1
    local trimmed = line:match("^%s*(.-)%s*$")

    if in_block then
      if trimmed:sub(1, 3) == "---" then in_block = false end
    elseif trimmed:sub(1, 3) == "---" then
      in_block = true
    elseif trimmed == "" or trimmed:sub(1, 1) == "#" then
      -- пустая строка или комментарий
    else
      local indent = line:match("^[ \t]*")
      if indent:find(" ") and indent:find("\t") then
        return nil, { msg = "mixed tabs and spaces in indentation", line = lineno, col = 1 }
      end

      local top = indent_stack[#indent_stack]
      if indent == top then
        -- тот же уровень
      elseif indent:sub(1, #top) == top then
        indent_stack[#indent_stack + 1] = indent
        tokens[#tokens + 1] = { type = "indent", line = lineno, col = 1 }
      else
        while #indent_stack > 1 and indent_stack[#indent_stack] ~= indent do
          indent_stack[#indent_stack] = nil
          tokens[#tokens + 1] = { type = "dedent", line = lineno, col = 1 }
        end
        if indent_stack[#indent_stack] ~= indent then
          return nil, { msg = "inconsistent indentation", line = lineno, col = 1 }
        end
      end

      local ok, err = scan_line(line, #indent + 1, lineno, tokens)
      if not ok then return nil, err end
      tokens[#tokens + 1] = { type = "newline", line = lineno, col = #line + 1 }
    end
  end

  while #indent_stack > 1 do
    indent_stack[#indent_stack] = nil
    tokens[#tokens + 1] = { type = "dedent", line = lineno, col = 1 }
  end
  tokens[#tokens + 1] = { type = "eof", line = lineno, col = 1 }
  return tokens
end

lexer.KEYWORDS = KEYWORDS
lexer.TEMPLATE_FUNCS = TEMPLATE_FUNCS

return lexer
