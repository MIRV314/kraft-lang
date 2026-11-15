-- Парсер Kraft. Заодно проверяет типы: переменная видна только после
-- объявления, поэтому проверку можно делать по ходу разбора.

local lexer = require("lexer")

local parser = {}

local TYPE_NAMES = {
  str = true, flint = true, bool = true, list = true, dict = true, NONE = true,
}

local COMPARE = {
  ["=="] = true, ["!="] = true, ["<"] = true, ["<="] = true, [">"] = true, [">="] = true,
}

local COMPOUND = {
  ["+="] = true, ["-="] = true, ["*="] = true, ["/="] = true,
  ["%="] = true, ["//="] = true, ["**="] = true,
}

local function is_const(name)
  return name:match("^[A-Z_][A-Z0-9_]*$") ~= nil
end

local function describe(t)
  if not t then return "end of file" end
  if t.type == "name" then return "name '" .. t.value .. "'" end
  if t.type == "number" then return "number " .. t.raw end
  if t.type == "string" then return "string" end
  if t.type == "template" then return "template" end
  if t.type == "kw" then return "keyword '" .. t.value .. "'" end
  if t.type == "op" then return "'" .. t.value .. "'" end
  if t.type == "newline" then return "end of line" end
  if t.type == "eof" then return "end of file" end
  if t.type == "indent" then return "indent" end
  if t.type == "dedent" then return "dedent" end
  return t.type
end

local P = {}
P.__index = P

function P:peek() return self.tokens[self.pos] end
function P:advance() local t = self.tokens[self.pos]; self.pos = self.pos + 1; return t end

function P:check(ty, value)
  local t = self:peek()
  if not t or t.type ~= ty then return false end
  if value ~= nil and t.value ~= value then return false end
  return true
end

function P:check_op(v) return self:check("op", v) end
function P:check_kw(v) return self:check("kw", v) end

function P:expect(ty, value, what)
  if not self:check(ty, value) then
    self:fail(self:peek(), "SYNTAX_ERROR", what or (ty .. (value and (" '" .. value .. "'") or "")), describe(self:peek()))
  end
  return self:advance()
end

function P:fail(tok, cat, expected, found)
  tok = tok or { line = 0, col = 1 }
  error({
    kraft_error = true, cat = cat, line = tok.line, col = tok.col,
    expected = expected, found = found, path = self.path,
  }, 0)
end

-- ---------- программа ----------

function P:parse_program()
  local stmts = {}
  while not self:check("eof") do
    if self:check("newline") then
      self:advance()
    elseif self:check("dedent") then
      self:advance()
    elseif self:check("indent") then
      self:fail(self:peek(), "SYNTAX_ERROR", "statement", "unexpected indent")
    else
      local s = self:parse_stmt()
      stmts[#stmts + 1] = s
      if not s.block_stmt then
        if self:check("newline") then
          self:advance()
        elseif not self:check("eof") then
          self:fail(self:peek(), "SYNTAX_ERROR", "end of line", describe(self:peek()))
        end
      end
    end
  end
  return { k = "program", stmts = stmts }
end

-- Блок после ':' — это newline, indent, стейтменты, dedent.
function P:parse_block()
  self:expect("newline", nil, "end of line after ':'")
  self:expect("indent", nil, "indented block")
  self.block_depth = self.block_depth + 1

  local stmts = {}
  while not self:check("dedent") and not self:check("eof") do
    if self:check("newline") then
      self:advance()
    else
      local s = self:parse_stmt()
      stmts[#stmts + 1] = s
      if not s.block_stmt then
        if self:check("newline") then
          self:advance()
        elseif not self:check("dedent") then
          self:fail(self:peek(), "SYNTAX_ERROR", "end of line", describe(self:peek()))
        end
      end
    end
  end

  if self:check("dedent") then self:advance() end
  self.block_depth = self.block_depth - 1
  return stmts
end

function P:parse_if()
  local tok = self:advance()
  local branches = {}

  local cond = self:parse_expr()
  self:expect("op", ":", "':'")
  branches[1] = { cond = cond, body = self:parse_block() }

  while self:check_kw("elif") do
    self:advance()
    local c = self:parse_expr()
    self:expect("op", ":", "':'")
    branches[#branches + 1] = { cond = c, body = self:parse_block() }
  end

  local else_body
  if self:check_kw("else") then
    self:advance()
    self:expect("op", ":", "':'")
    else_body = self:parse_block()
  end

  return {
    k = "if", branches = branches, else_body = else_body,
    block_stmt = true, line = tok.line, col = tok.col,
  }
end

function P:parse_while()
  local tok = self:advance()
  local cond = self:parse_expr()
  self:expect("op", ":", "':'")
  self.loop_depth = self.loop_depth + 1
  local body = self:parse_block()
  self.loop_depth = self.loop_depth - 1
  return {
    k = "while", cond = cond, body = body,
    block_stmt = true, line = tok.line, col = tok.col,
  }
end

-- Числовой for: `for i N` (0..N-1) или `for i a..b` / `for i a..b..step`.
function P:parse_for()
  local tok = self:advance()
  local name_tok = self:expect("name", nil, "loop variable")
  local name = name_tok.value

  if self:check_kw("in") then
    self:fail(self:peek(), "SYNTAX_ERROR", "numeric range (for i N or for i a..b)",
      "'in' (for-in needs collections, later)")
  end

  if is_const(name) then
    self:fail(name_tok, "CONST_ERROR", "variable", "constant '" .. name .. "'")
  end
  if self.vars[name] or self.for_names[name] then
    self:fail(name_tok, "REDECLARE_ERROR", "unique loop variable",
      "name '" .. name .. "' is already declared")
  end

  local function flint_operand(e, what)
    if e.t ~= "flint" and e.t ~= "NONE" then
      self:fail({ line = e.line, col = e.col }, "TYPE_ERROR",
        what .. " to be flint", e.t)
    end
    return e
  end

  local node = { k = "for", name = name, line = tok.line, col = tok.col }

  local first = flint_operand(self:parse_expr(), "loop bound")
  if self:check_op("..") then
    self:advance()
    local last = flint_operand(self:parse_expr(), "loop bound")
    local step
    if self:check_op("..") then
      self:advance()
      step = flint_operand(self:parse_expr(), "loop step")
    end
    node.form = "range"
    node.from = first
    node.to = last
    node.step = step
  else
    node.form = "upto"
    node.to = first
  end

  self:expect("op", ":", "':'")

  -- Переменная цикла видна только внутри тела и не может быть объявлена повторно.
  self.for_names[name] = true
  self.vars[name] = "flint"
  self.loop_depth = self.loop_depth + 1
  node.body = self:parse_block()
  self.loop_depth = self.loop_depth - 1
  self.vars[name] = nil

  node.block_stmt = true
  return node
end

-- func name(тип имя, ...) -> тип: — только верхний уровень.
function P:parse_func()
  local tok = self:advance()
  if self.in_func or self.block_depth > 0 then
    self:fail(tok, "SYNTAX_ERROR", "function at top level", "nested function")
  end

  local name_tok = self:expect("name", nil, "function name")
  local name = name_tok.value
  if is_const(name) then
    self:fail(name_tok, "CONST_ERROR", "function name", "constant '" .. name .. "'")
  end
  if self.funcs[name] or self.vars[name] then
    self:fail(name_tok, "REDECLARE_ERROR", "unique name",
      "name '" .. name .. "' is already declared")
  end

  self:expect("op", "(", "'('")
  local params = {}
  if not self:check_op(")") then
    while true do
      local pty_tok = self:peek()
      local pty = self:parse_type_name()
      if pty == "NONE" then
        self:fail(pty_tok, "TYPE_ERROR", "parameter type", "NONE")
      end
      local pn = self:expect("name", nil, "parameter name")
      for _, p in ipairs(params) do
        if p.name == pn.value then
          self:fail(pn, "REDECLARE_ERROR", "unique parameter name",
            "duplicate '" .. pn.value .. "'")
        end
      end
      params[#params + 1] = { name = pn.value, type = pty, line = pn.line, col = pn.col }
      if self:check_op(",") then self:advance() else break end
    end
  end
  self:expect("op", ")", "')'")

  local ret
  if self:check_op("->") then
    self:advance()
    local ret_tok = self:peek()
    ret = self:parse_type_name()
    if ret == "NONE" then
      self:fail(ret_tok, "SYNTAX_ERROR", "return type (omit '->' for NONE)", "NONE")
    end
  end
  self:expect("op", ":", "':'")

  -- Функция регистрируется до тела: так работает рекурсия с явным '->'.
  local fn = { params = params, ret = ret, ret_nullable = false, inferring = true }
  self.funcs[name] = fn

  -- Тело — своя область видимости: переменные файла не видны.
  local saved = {
    vars = self.vars, nullable = self.nullable, maybe_unset = self.maybe_unset,
    for_names = self.for_names, loop_depth = self.loop_depth,
    in_func = self.in_func, func_ret = self.func_ret, func_returns = self.func_returns,
  }
  self.vars = {}
  self.nullable = {}
  self.maybe_unset = {}
  self.for_names = {}
  for _, p in ipairs(params) do self.vars[p.name] = p.type end
  self.loop_depth = 0
  self.in_func = true
  self.func_ret = ret
  self.func_returns = {}

  local body = self:parse_block()

  local returns = self.func_returns
  self.vars, self.nullable, self.maybe_unset = saved.vars, saved.nullable, saved.maybe_unset
  self.for_names, self.loop_depth = saved.for_names, saved.loop_depth
  self.in_func, self.func_ret, self.func_returns = saved.in_func, saved.func_ret, saved.func_returns

  -- Тело без return в конце может «провалиться» — тогда результат NONE.
  local fallthrough = not (body[#body] and body[#body].k == "return")
  local nullable = fallthrough
  local seen

  for _, r in ipairs(returns) do
    if r.empty or r.type == "NONE" then
      nullable = true
    elseif ret then
      if r.type ~= ret then
        self:fail(r, "TYPE_ERROR", "return type " .. ret, r.type)
      end
    else
      if seen and seen ~= r.type then
        self:fail(r, "TYPE_ERROR",
          "all returns of '" .. name .. "' to have one type", seen .. " and " .. r.type)
      end
      seen = r.type
    end
  end

  if not ret then ret = seen or "NONE" end
  fn.ret = ret
  fn.ret_nullable = nullable
  fn.inferring = false

  return {
    k = "func", name = name, params = params, ret = ret, body = body,
    block_stmt = true, line = tok.line, col = tok.col,
  }
end

function P:parse_return()
  local tok = self:advance()
  if not self.in_func then
    self:fail(tok, "SCOPE_ERROR", "'return' inside a function", "'return' at top level")
  end

  local expr
  if self:check_op(":") then
    self:advance()
  else
    expr = self:parse_expr()
  end

  self.func_returns[#self.func_returns + 1] = {
    empty = (expr == nil), type = expr and expr.t or "NONE",
    line = tok.line, col = tok.col,
  }
  return { k = "return", expr = expr, line = tok.line, col = tok.col }
end

function P:parse_stmt()
  local t = self:peek()
  if t.type == "kw" and (t.value == "str" or t.value == "flint" or t.value == "bool") then
    return self:parse_decl()
  end
  if t.type == "kw" and t.value == "if" then
    return self:parse_if()
  end
  if t.type == "kw" and t.value == "while" then
    return self:parse_while()
  end
  if t.type == "kw" and t.value == "for" then
    return self:parse_for()
  end
  if t.type == "kw" and t.value == "func" then
    return self:parse_func()
  end
  if t.type == "kw" and t.value == "return" then
    return self:parse_return()
  end
  if t.type == "kw" and (t.value == "break" or t.value == "continue") then
    self:advance()
    if self.loop_depth == 0 then
      self:fail(t, "SCOPE_ERROR", "'break' or 'continue' inside a loop", "'" .. t.value .. "' outside a loop")
    end
    return { k = t.value, line = t.line, col = t.col }
  end
  if t.type == "name" and not lexer.TEMPLATE_FUNCS[t.value] then
    local nextt = self.tokens[self.pos + 1]
    if nextt and nextt.type == "op" and nextt.value == "=" then
      return self:parse_assign()
    end
    if nextt and nextt.type == "op" and COMPOUND[nextt.value] then
      return self:parse_compound()
    end
  end
  local e = self:parse_expr()
  return { k = "exprstmt", expr = e, line = e.line, col = e.col }
end

function P:parse_decl()
  local ty = self:advance().value
  local name_tok = self:expect("name", nil, "variable name")
  local name = name_tok.value

  if self.vars[name] or self.funcs[name] then
    self:fail(name_tok, "REDECLARE_ERROR", "unique name", "name '" .. name .. "' is already declared")
  end

  self:expect("op", "=", "'='")
  local expr = self:parse_expr()

  if expr.t ~= "NONE" and expr.t ~= ty then
    self:fail(
      { line = expr.line, col = expr.col },
      "TYPE_ERROR",
      "declaration of '" .. name .. "': type " .. ty,
      expr.t
    )
  end

  self.vars[name] = ty
  self.nullable[name] = (expr.t == "NONE" or expr.nullable) or nil
  -- Объявление внутри блока может не выполниться — тогда значение NONE (D11).
  if self.block_depth > 0 then self.maybe_unset[name] = true end
  return { k = "decl", type = ty, name = name, expr = expr, line = name_tok.line, col = name_tok.col }
end

function P:parse_assign()
  local name_tok = self:advance()
  local name = name_tok.value
  if not self.vars[name] then
    self:fail(name_tok, "NAME_ERROR", "declared variable", "name '" .. name .. "' is not declared")
  end
  if is_const(name) then
    self:fail(name_tok, "CONST_ERROR", "variable", "constant '" .. name .. "'")
  end
  self:expect("op", "=", "'='")
  local expr = self:parse_expr()
  if expr.t ~= "NONE" and expr.t ~= self.vars[name] then
    self:fail(
      { line = expr.line, col = expr.col },
      "TYPE_ERROR",
      "assignment to '" .. name .. "': type " .. self.vars[name],
      expr.t
    )
  end
  self.nullable[name] = (expr.t == "NONE" or expr.nullable) or nil
  return { k = "assign", name = name, expr = expr, line = name_tok.line, col = name_tok.col }
end

function P:parse_compound()
  local name_tok = self:advance()
  local name = name_tok.value
  if not self.vars[name] then
    self:fail(name_tok, "NAME_ERROR", "declared variable", "name '" .. name .. "' is not declared")
  end
  if is_const(name) then
    self:fail(name_tok, "CONST_ERROR", "variable", "constant '" .. name .. "'")
  end
  local op_tok = self:advance()
  local op = op_tok.value:sub(1, -2) -- "+=" -> "+"
  local expr = self:parse_expr()

  if self.vars[name] ~= "flint" or (expr.t ~= "flint" and expr.t ~= "NONE") then
    self:fail(op_tok, "TYPE_ERROR", "numeric operands of '" .. op_tok.value .. "'", expr.t)
  end

  local maybe = (self.nullable[name] or self.maybe_unset[name]) or nil
  self.nullable[name] = nil
  return {
    k = "compound", name = name, op = op, expr = expr, nullable = maybe,
    line = name_tok.line, col = name_tok.col,
  }
end

-- ---------- выражения ----------

function P:parse_expr()
  return self:parse_or()
end

function P:parse_or()
  local e = self:parse_and()
  while self:check_kw("OR") do
    local tok = self:advance()
    local r = self:parse_and()
    e = { k = "bin", op = "OR", a = e, b = r, t = "bool", line = tok.line, col = tok.col }
  end
  return e
end

function P:parse_and()
  local e = self:parse_not()
  while self:check_kw("AND") do
    local tok = self:advance()
    local r = self:parse_not()
    e = { k = "bin", op = "AND", a = e, b = r, t = "bool", line = tok.line, col = tok.col }
  end
  return e
end

function P:parse_not()
  if self:check_kw("NOT") then
    local tok = self:advance()
    local e = self:parse_not()
    return { k = "un", op = "NOT", a = e, t = "bool", line = tok.line, col = tok.col }
  end
  return self:parse_cmp()
end

function P:parse_cmp()
  local first = self:parse_add()

  if self:check_kw("is") then
    local tok = self:advance()
    local ty = self:parse_type_name()
    return { k = "is", a = first, typename = ty, t = "bool", line = tok.line, col = tok.col }
  end

  local ops, operands = {}, { first }
  while true do
    local t = self:peek()
    if not (t and t.type == "op" and COMPARE[t.value]) then break end
    self:advance()
    ops[#ops + 1] = { op = t.value, line = t.line, col = t.col }
    operands[#operands + 1] = self:parse_add()
  end

  if #ops == 0 then return first end

  for i, o in ipairs(ops) do
    local a, b = operands[i], operands[i + 1]
    if o.op ~= "==" and o.op ~= "!=" then
      local ok = (a.t == b.t) and (a.t == "flint" or a.t == "str")
      if not ok and a.t ~= "NONE" and b.t ~= "NONE" then
        self:fail(o, "TYPE_ERROR", "comparable operands of '" .. o.op .. "'", a.t .. " and " .. b.t)
      end
    end
  end

  if #ops == 1 then
    return {
      k = "bin", op = ops[1].op, a = operands[1], b = operands[2],
      t = "bool", line = ops[1].line, col = ops[1].col,
    }
  end

  return { k = "chain", ops = ops, operands = operands, t = "bool", line = first.line, col = first.col }
end

function P:parse_type_name()
  local t = self:peek()
  if t and t.type == "kw" and TYPE_NAMES[t.value] then
    self:advance()
    return t.value
  end
  self:fail(t, "TYPE_ERROR", "type name", describe(t))
end

function P:parse_add()
  local e = self:parse_mul()
  while self:check_op("+") or self:check_op("-") do
    local tok = self:advance()
    local r = self:parse_mul()
    if tok.value == "+" and (e.t == "str" or r.t == "str") then
      self:fail(tok, "CONCATENATE_NOT_SUPPORT", "numeric operands of '+'", "str")
    end
    if (e.t ~= "flint" and e.t ~= "NONE") or (r.t ~= "flint" and r.t ~= "NONE") then
      self:fail(tok, "TYPE_ERROR", "operands of '" .. tok.value .. "' to be flint", e.t .. " and " .. r.t)
    end
    e = { k = "bin", op = tok.value, a = e, b = r, t = "flint", line = tok.line, col = tok.col }
  end
  return e
end

function P:parse_mul()
  local e = self:parse_unary()
  while self:check_op("*") or self:check_op("/") or self:check_op("//") or self:check_op("%") do
    local tok = self:advance()
    local r = self:parse_unary()
    if (e.t ~= "flint" and e.t ~= "NONE") or (r.t ~= "flint" and r.t ~= "NONE") then
      self:fail(tok, "TYPE_ERROR", "operands of '" .. tok.value .. "' to be flint", e.t .. " and " .. r.t)
    end
    e = { k = "bin", op = tok.value, a = e, b = r, t = "flint", line = tok.line, col = tok.col }
  end
  return e
end

function P:parse_unary()
  if self:check_op("-") then
    local tok = self:advance()
    local e = self:parse_unary()
    if e.t ~= "flint" and e.t ~= "NONE" then
      self:fail(tok, "TYPE_ERROR", "operand of unary '-' to be flint", e.t)
    end
    return { k = "un", op = "-", a = e, t = "flint", line = tok.line, col = tok.col }
  end
  return self:parse_power()
end

function P:parse_power()
  local base = self:parse_primary()
  if self:check_op("**") then
    local tok = self:advance()
    local exp = self:parse_unary() -- правоассоциативно: 2**3**2 = 2**(3**2)
    if (base.t ~= "flint" and base.t ~= "NONE") or (exp.t ~= "flint" and exp.t ~= "NONE") then
      self:fail(tok, "TYPE_ERROR", "operands of '**' to be flint", base.t .. " and " .. exp.t)
    end
    return { k = "bin", op = "**", a = base, b = exp, t = "flint", line = tok.line, col = tok.col }
  end
  return base
end

function P:parse_primary()
  local e = self:parse_atom()
  return self:parse_postfix(e)
end

-- Постфикс: s[i], s[a..b], s[a..b..step], s.method(...).
function P:parse_postfix(e)
  while true do
    if self:check_op("[") then
      self:advance()
      e = self:parse_index(e)
    elseif self:check_op(".") then
      self:advance()
      e = self:parse_method(e)
    else
      return e
    end
  end
end

function P:parse_index(base)
  local open = self:peek()

  local from
  if self:check_op("..") then
    -- s[..to]
  else
    from = self:parse_expr()
  end

  if self:check_op("..") then
    self:advance()
    local to
    if not self:check_op("]") then to = self:parse_expr() end
    local step
    if self:check_op("..") then
      self:advance()
      step = self:parse_expr()
    end
    self:expect("op", "]", "']'")

    if base.t ~= "str" and base.t ~= "NONE" then
      self:fail(open, "TYPE_ERROR", "string receiver of a slice", base.t)
    end
    for _, b in ipairs({ from, to, step }) do
      if b and b.t ~= "flint" and b.t ~= "NONE" then
        self:fail({ line = b.line, col = b.col }, "TYPE_ERROR", "slice bound to be flint", b.t)
      end
    end
    return {
      k = "slice", base = base, from = from, to = to, step = step, t = "str",
      line = open.line, col = open.col,
    }
  end

  self:expect("op", "]", "']'")
  if base.t ~= "str" and base.t ~= "NONE" then
    self:fail(open, "TYPE_ERROR", "string receiver of an index", base.t)
  end
  if from.t ~= "flint" and from.t ~= "NONE" then
    self:fail({ line = from.line, col = from.col }, "TYPE_ERROR", "index to be flint", from.t)
  end
  return {
    k = "index", base = base, index = from, t = "str",
    line = open.line, col = open.col,
  }
end

local STR_METHODS = {
  part = { min = 1, max = 2, args = { "flint", "flint" }, t = "str" },
  find = { min = 1, max = 1, args = { "str" }, t = "flint", nullable = true },
  contains = { min = 1, max = 1, args = { "str" }, t = "bool" },
  preff = { min = 1, max = 1, args = { "str" }, t = "bool" },
  suff = { min = 1, max = 1, args = { "str" }, t = "bool" },
  trim = { min = 0, max = 0, args = {}, t = "str" },
  triml = { min = 0, max = 0, args = {}, t = "str" },
  trimr = { min = 0, max = 0, args = {}, t = "str" },
  replace = { min = 2, max = 2, args = { "str", "str" }, t = "str" },
  count = { min = 1, max = 1, args = { "str" }, t = "flint" },
}

function P:parse_method(base)
  local name_tok = self:expect("name", nil, "method name")
  local name = name_tok.value

  self:expect("op", "(", "'('")
  local args = {}
  if not self:check_op(")") then
    while true do
      args[#args + 1] = self:parse_expr()
      if self:check_op(",") then self:advance() else break end
    end
  end
  self:expect("op", ")", "')'")

  if base.t ~= "str" and base.t ~= "NONE" then
    self:fail(name_tok, "TYPE_ERROR", "string receiver of '" .. name .. "'", base.t)
  end

  local m = STR_METHODS[name]
  if not m then
    self:fail(name_tok, "NAME_ERROR", "string method", "unknown method '" .. name .. "'")
  end

  if #args < m.min or #args > m.max then
    self:fail(name_tok, "ARGCOUNT_ERROR",
      m.min .. (m.min ~= m.max and (".." .. m.max) or "") .. " argument(s) to '" .. name .. "'",
      #args .. " argument(s)")
  end
  for i, a in ipairs(args) do
    local at = m.args[i]
    if at and a.t ~= "NONE" and a.t ~= at then
      self:fail({ line = a.line, col = a.col }, "TYPE_ERROR",
        "argument " .. i .. " of '" .. name .. "' to be " .. at, a.t)
    end
  end

  return {
    k = "method", base = base, name = name, args = args, argtypes = m.args, t = m.t,
    nullable = m.nullable or nil,
    line = name_tok.line, col = name_tok.col,
  }
end

function P:parse_atom()
  local t = self:peek()

  if t.type == "number" then
    self:advance()
    return { k = "num", value = t.value, t = "flint", line = t.line, col = t.col }
  end

  if t.type == "string" then
    self:advance()
    return { k = "str", parts = self:parse_parts(t), t = "str", line = t.line, col = t.col }
  end

  if t.type == "kw" and t.value == "TRUE" then
    self:advance()
    return { k = "bool", value = true, t = "bool", line = t.line, col = t.col }
  end

  if t.type == "kw" and t.value == "FALSE" then
    self:advance()
    return { k = "bool", value = false, t = "bool", line = t.line, col = t.col }
  end

  if t.type == "kw" and t.value == "NONE" then
    self:advance()
    return { k = "none", t = "NONE", line = t.line, col = t.col }
  end

  if t.type == "name" and lexer.TEMPLATE_FUNCS[t.value] then
    self:advance()
    self:expect("op", "(", "'('")
    local tpl = self:expect("template", nil, "template")
    self:expect("op", ")", "')'")
    local ty = (t.value == "input") and "str" or "NONE"
    return {
      k = "call", fn = t.value, parts = self:parse_parts(tpl), t = ty,
      line = t.line, col = t.col,
    }
  end

  if t.type == "name" then
    local nextt = self.tokens[self.pos + 1]
    if nextt and nextt.type == "op" and nextt.value == "(" then
      return self:parse_call()
    end
    self:advance()
    local ty = self.vars[t.value]
    if not ty then
      self:fail(t, "NAME_ERROR", "declared name", "undeclared '" .. t.value .. "'")
    end
    return {
      k = "var", name = t.value, t = ty,
      nullable = (self.nullable[t.value] or self.maybe_unset[t.value]) or nil,
      line = t.line, col = t.col,
    }
  end

  if t.type == "op" and t.value == "(" then
    self:advance()
    local e = self:parse_expr()
    self:expect("op", ")", "')'")
    return e
  end

  self:fail(t, "SYNTAX_ERROR", "expression", describe(t))
end

function P:parse_call()
  local name_tok = self:advance()
  local name = name_tok.value
  local fn = self.funcs[name]
  if not fn then
    self:fail(name_tok, "NAME_ERROR", "declared function", "undeclared function '" .. name .. "'")
  end
  if fn.inferring and not fn.ret then
    self:fail(name_tok, "TYPE_ERROR",
      "explicit '->' for recursion",
      "'" .. name .. "' is called while its return type is inferred")
  end

  self:expect("op", "(", "'('")
  local args = {}
  if not self:check_op(")") then
    while true do
      args[#args + 1] = self:parse_expr()
      if self:check_op(",") then self:advance() else break end
    end
  end
  self:expect("op", ")", "')'")

  if #args ~= #fn.params then
    self:fail(name_tok, "ARGCOUNT_ERROR",
      #fn.params .. " argument(s) to '" .. name .. "'",
      #args .. " argument(s)")
  end

  for i, a in ipairs(args) do
    local pt = fn.params[i].type
    if a.t ~= "NONE" and a.t ~= pt then
      self:fail({ line = a.line, col = a.col }, "TYPE_ERROR",
        "argument " .. i .. " of '" .. name .. "' to be " .. pt, a.t)
    end
  end

  return {
    k = "call_user", name = name, args = args, t = fn.ret,
    nullable = fn.ret_nullable or nil,
    line = name_tok.line, col = name_tok.col,
  }
end

-- Части строки/шаблона: текст и выражения.
function P:parse_parts(tpl)
  local parts = {}
  for _, p in ipairs(tpl.parts) do
    if p.kind == "text" then
      parts[#parts + 1] = { kind = "text", value = p.value }
    else
      local toks, lerr = lexer.tokenize(p.src, self.path)
      if not toks then
        local eline = p.line + (lerr.line or 1) - 1
        local ecol = (lerr.line == 1) and (p.col + (lerr.col or 1) - 1) or (lerr.col or 1)
        error({
          kraft_error = true, cat = "SYNTAX_ERROR",
          line = eline, col = ecol,
          msg = lerr.msg, path = self.path,
        }, 0)
      end
      for _, tk in ipairs(toks) do
        tk.line = tk.line + p.line - 1
        if tk.line == p.line then tk.col = tk.col + p.col - 1 end
      end
      local sub = setmetatable({
        tokens = toks, pos = 1, path = self.path, vars = self.vars,
        nullable = self.nullable, maybe_unset = self.maybe_unset,
        for_names = self.for_names, funcs = self.funcs,
        in_func = self.in_func, func_ret = self.func_ret,
        func_returns = self.func_returns,
        block_depth = self.block_depth, loop_depth = self.loop_depth,
      }, P)
      local e = sub:parse_expr()
      local rest = sub:peek()
      if rest and rest.type ~= "newline" and rest.type ~= "eof" then
        sub:fail(rest, "SYNTAX_ERROR", "end of expression", describe(rest))
      end
      parts[#parts + 1] = { kind = "expr", expr = e }
    end
  end
  return parts
end

function parser.parse(tokens, path)
  local self = setmetatable({
    tokens = tokens, pos = 1, path = path, vars = {}, nullable = {},
    maybe_unset = {}, for_names = {}, funcs = {},
    in_func = false, func_ret = nil, func_returns = nil,
    block_depth = 0, loop_depth = 0,
  }, P)
  return self:parse_program()
end

return parser
