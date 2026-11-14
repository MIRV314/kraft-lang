-- Кодоген: AST Kraft -> текст Lua.

local codegen = {}

local function lua_str(s)
  s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
  s = s:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
  s = s:gsub("[%z\1-\31]", function(c) return string.format("\\%d", c:byte()) end)
  return '"' .. s .. '"'
end

function codegen.generate(ast, opts)
  local out = {}
  local indent = 0
  local function emit(s)
    out[#out + 1] = string.rep("    ", indent) .. s
  end

  local lua_vars = {}
  local decl_order = {}
  local counter = 0
  local function lua_name(name)
    if not lua_vars[name] then
      counter = counter + 1
      lua_vars[name] = "v_" .. counter
    end
    return lua_vars[name]
  end

  -- Все объявления поднимаются в начало функции (D11, D43).
  local function collect(stmts)
    for _, s in ipairs(stmts) do
      if s.k == "decl" then
        lua_name(s.name)
        decl_order[#decl_order + 1] = s.name
      elseif s.k == "if" then
        for _, b in ipairs(s.branches) do collect(b.body) end
        if s.else_body then collect(s.else_body) end
      elseif s.k == "while" then
        collect(s.body)
      elseif s.k == "for" then
        collect(s.body)
      end
    end
  end
  collect(ast.stmts)

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

  -- ---------- стейтменты ----------

  local loop_stack = {}
  local loop_id = 0
  local emit_stmts

  local function emit_stmt(s)
    if s.k == "decl" then
      emit(lua_name(s.name) .. " = " .. emit_expr(s.expr))

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

    elseif s.k == "if" then
      for i, b in ipairs(s.branches) do
        if i == 1 then
          emit("if krt.truthy(" .. emit_expr(b.cond) .. ") then")
        else
          emit("elseif krt.truthy(" .. emit_expr(b.cond) .. ") then")
        end
        indent = indent + 1
        emit_stmts(b.body)
        indent = indent - 1
      end
      if s.else_body then
        emit("else")
        indent = indent + 1
        emit_stmts(s.else_body)
        indent = indent - 1
      end
      emit("end")

    elseif s.k == "while" then
      loop_id = loop_id + 1
      local id = loop_id
      local cont = "__continue_" .. id
      local brk = "__break_" .. id
      emit("while krt.truthy(" .. emit_expr(s.cond) .. ") do")
      indent = indent + 1
      loop_stack[#loop_stack + 1] = { cont = cont, brk = brk }
      emit_stmts(s.body)
      emit("::" .. cont .. "::")
      loop_stack[#loop_stack] = nil
      indent = indent - 1
      emit("end")
      emit("::" .. brk .. "::")

    elseif s.k == "break" then
      emit("goto " .. loop_stack[#loop_stack].brk)

    elseif s.k == "continue" then
      emit("goto " .. loop_stack[#loop_stack].cont)

    elseif s.k == "for" then
      loop_id = loop_id + 1
      local id = loop_id
      local cont = "__continue_" .. id
      local brk = "__break_" .. id
      local v = lua_name(s.name)
      local to = "__to_" .. id

      emit("do")
      indent = indent + 1
      if s.form == "upto" then
        emit("local " .. v .. " = 0")
        emit("local " .. to .. " = " .. numeric(s.to))
        emit("while " .. v .. " < " .. to .. " do")
      else
        local step = "__step_" .. id
        emit("local " .. v .. " = " .. numeric(s.from))
        emit("local " .. to .. " = " .. numeric(s.to))
        emit("local " .. step .. " = " .. (s.step and numeric(s.step) or "1"))
        emit("while ((" .. step .. " > 0) and (" .. v .. " < " .. to ..
          ")) or ((" .. step .. " < 0) and (" .. v .. " > " .. to .. ")) do")
      end

      indent = indent + 1
      loop_stack[#loop_stack + 1] = { cont = cont, brk = brk }
      emit_stmts(s.body)
      emit("::" .. cont .. "::")
      if s.form == "upto" then
        emit(v .. " = " .. v .. " + 1")
      else
        emit(v .. " = " .. v .. " + __step_" .. id)
      end
      loop_stack[#loop_stack] = nil
      indent = indent - 1
      emit("end")
      indent = indent - 1
      emit("end")
      emit("::" .. brk .. "::")

    else
      error("codegen: unknown statement " .. tostring(s.k))
    end
  end

  emit_stmts = function(stmts)
    for _, s in ipairs(stmts) do emit_stmt(s) end
  end

  -- ---------- шапка ----------

  emit("-- generated by kraft")
  emit("local __KRAFT_SOURCE = " .. lua_str(opts.path))
  emit("local krt = (function()")
  emit(opts.krt)
  emit("end)()")
  emit("krt.run(function()")
  indent = 1

  if #decl_order > 0 then
    local names, nones = {}, {}
    for _, n in ipairs(decl_order) do
      names[#names + 1] = lua_name(n)
      nones[#nones + 1] = "krt.NONE"
    end
    emit("local " .. table.concat(names, ", ") .. " = " .. table.concat(nones, ", "))
  end

  emit_stmts(ast.stmts)

  indent = 0
  emit("end)")
  return table.concat(out, "\n") .. "\n"
end

return codegen
