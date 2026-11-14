-- Кодоген: AST Kraft -> текст Lua.

local codegen = {}

local function lua_str(s)
  s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
  s = s:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
  s = s:gsub("[%z\1-\31]", function(c) return string.format("\\%d", c:byte()) end)
  return '"' .. s .. '"'
end

local function is_pure(e)
  if e.k == "num" or e.k == "var" or e.k == "bool" or e.k == "none" then return true end
  if e.k == "str" then
    for _, p in ipairs(e.parts) do
      if p.kind ~= "text" then return false end
    end
    return true
  end
  return false
end

function codegen.generate(ast, opts)
  local out = {}
  local function emit(s) out[#out + 1] = s end

  local lua_vars = {}
  local counter = 0
  local function lua_name(name)
    if not lua_vars[name] then
      counter = counter + 1
      lua_vars[name] = "v_" .. counter
    end
    return lua_vars[name]
  end

  local emit_expr

  local function emit_parts(parts)
    if #parts == 0 then return '""' end
    local pieces = {}
    for _, p in ipairs(parts) do
      if p.kind == "text" then
        pieces[#pieces + 1] = lua_str(p.value)
      else
        pieces[#pieces + 1] = "krt.tostr(" .. emit_expr(p.expr) .. ")"
      end
    end
    if #pieces == 1 then return pieces[1] end
    return "(" .. table.concat(pieces, " .. ") .. ")"
  end

  local function numeric(e)
    if e.t == "NONE" or e.nullable then return "krt.as_flint(" .. emit_expr(e) .. ")" end
    return emit_expr(e)
  end

  local function ordered(e, other)
    local x = emit_expr(e)
    if e.t == "NONE" or e.nullable then
      local ty = (e.t == "NONE") and other.t or e.t
      if ty == "str" then return "krt.as_str(" .. x .. ")" end
      return "krt.as_flint(" .. x .. ")"
    end
    return x
  end

  emit_expr = function(e)
    local k = e.k

    if k == "num" then
      return string.format("(%.14g)", e.value)
    elseif k == "bool" then
      return e.value and "true" or "false"
    elseif k == "none" then
      return "krt.NONE"
    elseif k == "var" then
      return lua_name(e.name)
    elseif k == "str" then
      return emit_parts(e.parts)
    elseif k == "call" then
      if e.fn == "show" then
        return "krt.show(" .. emit_parts(e.parts) .. ")"
      elseif e.fn == "show_err" then
        return "krt.show_err(" .. emit_parts(e.parts) .. ")"
      else
        return "krt.input(" .. emit_parts(e.parts) .. ")"
      end
    elseif k == "un" then
      if e.op == "-" then
        return "(-(" .. numeric(e.a) .. "))"
      end
      return "(not krt.truthy(" .. emit_expr(e.a) .. "))"
    elseif k == "is" then
      local x = emit_expr(e.a)
      local ty = e.typename
      if ty == "flint" then return "(type(" .. x .. ') == "number")' end
      if ty == "str" then return "(type(" .. x .. ') == "string")' end
      if ty == "bool" then return "(type(" .. x .. ') == "boolean")' end
      if ty == "list" then return "krt.is_list(" .. x .. ")" end
      if ty == "dict" then return "krt.is_dict(" .. x .. ")" end
      return "(" .. x .. " == krt.NONE or " .. x .. " == nil)"
    elseif k == "bin" then
      local op = e.op
      if op == "+" then return "(" .. numeric(e.a) .. " + " .. numeric(e.b) .. ")" end
      if op == "-" then return "(" .. numeric(e.a) .. " - " .. numeric(e.b) .. ")" end
      if op == "*" then return "(" .. numeric(e.a) .. " * " .. numeric(e.b) .. ")" end
      if op == "/" then return "krt.div(" .. numeric(e.a) .. ", " .. numeric(e.b) .. ")" end
      if op == "//" then return "krt.idiv(" .. numeric(e.a) .. ", " .. numeric(e.b) .. ")" end
      if op == "%" then return "krt.mod(" .. numeric(e.a) .. ", " .. numeric(e.b) .. ")" end
      if op == "**" then return "krt.pow(" .. numeric(e.a) .. ", " .. numeric(e.b) .. ")" end
      if op == "==" then return "(" .. emit_expr(e.a) .. " == " .. emit_expr(e.b) .. ")" end
      if op == "!=" then return "(" .. emit_expr(e.a) .. " ~= " .. emit_expr(e.b) .. ")" end
      if op == "<" then return "(" .. ordered(e.a, e.b) .. " < " .. ordered(e.b, e.a) .. ")" end
      if op == "<=" then return "(" .. ordered(e.a, e.b) .. " <= " .. ordered(e.b, e.a) .. ")" end
      if op == ">" then return "(" .. ordered(e.a, e.b) .. " > " .. ordered(e.b, e.a) .. ")" end
      if op == ">=" then return "(" .. ordered(e.a, e.b) .. " >= " .. ordered(e.b, e.a) .. ")" end
      if op == "AND" then return "(krt.truthy(" .. emit_expr(e.a) .. ") and krt.truthy(" .. emit_expr(e.b) .. "))" end
      if op == "OR" then return "(krt.truthy(" .. emit_expr(e.a) .. ") or krt.truthy(" .. emit_expr(e.b) .. "))" end
      error("codegen: unknown operator " .. tostring(op))
    elseif k == "chain" then
      -- средний операнд вычисляется один раз: (function() local t = ...; return ... end)()
      local lines = {}
      local prev = emit_expr(e.operands[1])
      local prev_node = e.operands[1]
      local conds = {}
      for i, o in ipairs(e.ops) do
        local rhs_node = e.operands[i + 1]
        local rhs
        if i < #e.ops then
          rhs = "__t" .. i
          lines[#lines + 1] = "local " .. rhs .. " = " .. emit_expr(rhs_node)
        else
          rhs = emit_expr(rhs_node)
        end
        local l, r = prev, rhs
        if o.op ~= "==" and o.op ~= "!=" then
          if prev_node.t == "NONE" or prev_node.nullable then
            if prev_node.t == "str" then l = "krt.as_str(" .. l .. ")" else l = "krt.as_flint(" .. l .. ")" end
          end
          if rhs_node.t == "NONE" or rhs_node.nullable then
            if rhs_node.t == "str" then r = "krt.as_str(" .. r .. ")" else r = "krt.as_flint(" .. r .. ")" end
          end
        end
        if o.op == "==" then conds[#conds + 1] = "(" .. l .. " == " .. r .. ")"
        elseif o.op == "!=" then conds[#conds + 1] = "(" .. l .. " ~= " .. r .. ")"
        elseif o.op == "<" then conds[#conds + 1] = "(" .. l .. " < " .. r .. ")"
        elseif o.op == "<=" then conds[#conds + 1] = "(" .. l .. " <= " .. r .. ")"
        elseif o.op == ">" then conds[#conds + 1] = "(" .. l .. " > " .. r .. ")"
        elseif o.op == ">=" then conds[#conds + 1] = "(" .. l .. " >= " .. r .. ")" end
        prev = rhs
        prev_node = rhs_node
      end
      return "(function() " .. table.concat(lines, "; ") .. "; return " .. table.concat(conds, " and ") .. " end)()"
    end

    error("codegen: unknown node " .. tostring(k))
  end

  emit("-- generated by kraft")
  emit("local __KRAFT_SOURCE = " .. lua_str(opts.path))
  emit("local krt = (function()")
  emit(opts.krt)
  emit("end)()")
  emit("krt.run(function()")

  for _, s in ipairs(ast.stmts) do
    if s.k == "decl" then
      emit("local " .. lua_name(s.name) .. " = " .. emit_expr(s.expr))
    elseif s.k == "assign" then
      emit(lua_name(s.name) .. " = " .. emit_expr(s.expr))
    elseif s.k == "compound" then
      local v = lua_name(s.name)
      local rhs = numeric(s.expr)
      local op = s.op
      local expr
      if op == "+" then expr = v .. " + " .. rhs
      elseif op == "-" then expr = v .. " - " .. rhs
      elseif op == "*" then expr = v .. " * " .. rhs
      elseif op == "/" then expr = "krt.div(" .. v .. ", " .. rhs .. ")"
      elseif op == "//" then expr = "krt.idiv(" .. v .. ", " .. rhs .. ")"
      elseif op == "%" then expr = "krt.mod(" .. v .. ", " .. rhs .. ")"
      elseif op == "**" then expr = "krt.pow(" .. v .. ", " .. rhs .. ")"
      else error("codegen: unknown compound " .. tostring(op)) end
      emit(v .. " = " .. expr)
    elseif s.k == "exprstmt" then
      emit(emit_expr(s.expr))
    end
  end

  emit("end)")
  return table.concat(out, "\n") .. "\n"
end

return codegen
