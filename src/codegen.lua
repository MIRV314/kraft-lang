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
  local counter = 0
  local function lua_name(name)
    if not lua_vars[name] then
      counter = counter + 1
      lua_vars[name] = "v_" .. counter
    end
    return lua_vars[name]
  end

  local lua_funcs = {}
  local func_counter = 0
  local function lua_func(name)
    if not lua_funcs[name] then
      func_counter = func_counter + 1
      lua_funcs[name] = "f_" .. func_counter
    end
    return lua_funcs[name]
  end

  -- Объявления поднимаются в начало своей функции (D11, D43).
  -- Тела функций — отдельные области, сюда не заходим.
  local current_ret = nil
  local function collect_scope(stmts)
    local names = {}
    local function walk(list)
      for _, s in ipairs(list) do
        if s.k == "decl" then
          lua_name(s.name)
          names[#names + 1] = s.name
        elseif s.k == "if" then
          for _, b in ipairs(s.branches) do walk(b.body) end
          if s.else_body then walk(s.else_body) end
        elseif s.k == "while" or s.k == "for" or s.k == "for_in" then
          walk(s.body)
        end
      end
    end
    walk(stmts)
    return names
  end

  local function emit_hoist(names)
    if #names == 0 then return end
    local lua, nones = {}, {}
    for _, n in ipairs(names) do
      lua[#lua + 1] = lua_name(n)
      nones[#nones + 1] = "krt.NONE"
    end
    emit("local " .. table.concat(lua, ", ") .. " = " .. table.concat(nones, ", "))
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
    if e.t == "NONE" or e.t == "any" or e.nullable then
      return "krt.as_flint(" .. emit_expr(e) .. ")"
    end
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

  local function as_str(e)
    local x = emit_expr(e)
    if e.t == "NONE" or e.t == "any" or e.nullable then
      return "krt.as_str(" .. x .. ")"
    end
    return x
  end

  local function as_bool(e)
    local x = emit_expr(e)
    if e.t == "NONE" or e.t == "any" or e.nullable then
      return "krt.as_bool(" .. x .. ")"
    end
    return x
  end

  local function as_list(e)
    local x = emit_expr(e)
    if e.t == "NONE" or e.t == "any" or e.nullable then
      return "krt.as_list(" .. x .. ")"
    end
    return x
  end

  local function as_dict(e)
    local x = emit_expr(e)
    if e.t == "NONE" or e.t == "any" or e.nullable then
      return "krt.as_dict(" .. x .. ")"
    end
    return x
  end

  local function checked(e, ty)
    if e.t == "any" and not e.nullable then
      if ty == "flint" then return "krt.as_flint(" .. emit_expr(e) .. ")" end
      if ty == "str" then return "krt.as_str(" .. emit_expr(e) .. ")" end
      if ty == "bool" then return "krt.as_bool(" .. emit_expr(e) .. ")" end
      if ty == "list" then return "krt.as_list(" .. emit_expr(e) .. ")" end
      if ty == "dict" then return "krt.as_dict(" .. emit_expr(e) .. ")" end
    end
    return emit_expr(e)
  end

  local function cmp(op, a, b)
    if a.t == "any" or b.t == "any" then
      local fn = ({ ["<"] = "lt", ["<="] = "le", [">"] = "gt", [">="] = "ge" })[op]
      return "krt." .. fn .. "(" .. emit_expr(a) .. ", " .. emit_expr(b) .. ")"
    end
    return "(" .. ordered(a, b) .. " " .. op .. " " .. ordered(b, a) .. ")"
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
    elseif k == "builtin" then
      local name = e.name
      local a = e.args
      if name == "len" then
        return "krt.len(" .. emit_expr(a[1]) .. ")"
      elseif name == "type" then
        return "krt.typeof(" .. emit_expr(a[1]) .. ")"
      elseif name == "str" then
        return "krt.tostr(" .. emit_expr(a[1]) .. ")"
      elseif name == "flint" then
        return "krt.to_flint(" .. emit_expr(a[1]) .. ")"
      elseif name == "read_file" then
        return "krt.read_file(" .. as_str(a[1]) .. ")"
      elseif name == "write_file" then
        return "krt.write_file(" .. as_str(a[1]) .. ", " .. as_str(a[2]) .. ")"
      elseif name == "file_exists" then
        return "krt.file_exists(" .. as_str(a[1]) .. ")"
      elseif name == "args" then
        return "krt.args()"
      elseif name == "exit" then
        return "krt.exit(" .. numeric(a[1]) .. ")"
      elseif name == "time_ms" then
        return "krt.time_ms()"
      elseif name == "is_tty" then
        return "krt.is_tty()"
      end
      error("codegen: unknown builtin " .. tostring(name))
    elseif k == "call_user" then
      local args = {}
      for i, a in ipairs(e.args) do
        local pt = e.ptypes[i]
        if a.t == "any" or a.t == "NONE" or a.nullable then
          if pt == "flint" then args[#args + 1] = "krt.as_flint(" .. emit_expr(a) .. ")"
          elseif pt == "str" then args[#args + 1] = "krt.as_str(" .. emit_expr(a) .. ")"
          elseif pt == "bool" then args[#args + 1] = "krt.as_bool(" .. emit_expr(a) .. ")"
          elseif pt == "list" then args[#args + 1] = "krt.as_list(" .. emit_expr(a) .. ")"
          elseif pt == "dict" then args[#args + 1] = "krt.as_dict(" .. emit_expr(a) .. ")"
          else args[#args + 1] = emit_expr(a) end
        else
          args[#args + 1] = emit_expr(a)
        end
      end
      return lua_func(e.name) .. "(" .. table.concat(args, ", ") .. ")"
    elseif k == "list" then
      local items = {}
      for i, it in ipairs(e.items) do items[i] = emit_expr(it) end
      return "krt.list({" .. table.concat(items, ", ") .. "})"
    elseif k == "dict" then
      local expr = "krt.dict()"
      for _, p in ipairs(e.pairs) do
        expr = "krt.dict_set(" .. expr .. ", " .. lua_str(p.key) .. ", " .. emit_expr(p.value) .. ")"
      end
      return expr
    elseif k == "dget" then
      return "krt.dict_get(" .. as_dict(e.base) .. ", " .. lua_str(e.key) .. ")"
    elseif k == "index" then
      if e.base.t == "list" then
        return "krt.list_index(" .. as_list(e.base) .. ", " .. numeric(e.index) .. ")"
      elseif e.base.t == "any" then
        return "krt.index(" .. emit_expr(e.base) .. ", " .. numeric(e.index) .. ")"
      end
      return "krt.str_index(" .. as_str(e.base) .. ", " .. numeric(e.index) .. ")"
    elseif k == "slice" then
      local fn
      local recv
      if e.base.t == "list" then
        fn, recv = "list_slice", as_list(e.base)
      elseif e.base.t == "any" then
        fn, recv = "slice", emit_expr(e.base)
      else
        fn, recv = "str_slice", as_str(e.base)
      end
      local parts = {
        recv,
        e.from and numeric(e.from) or "nil",
        e.to and numeric(e.to) or "nil",
      }
      if e.step then parts[#parts + 1] = numeric(e.step) end
      return "krt." .. fn .. "(" .. table.concat(parts, ", ") .. ")"
    elseif k == "method" then
      local recv
      if e.base.t == "list" then recv = as_list(e.base)
      elseif e.base.t == "dict" then recv = as_dict(e.base)
      else recv = as_str(e.base) end
      local args = { recv }
      for i, a in ipairs(e.args) do
        local at = e.argtypes[i]
        if at == "str" then
          args[#args + 1] = as_str(a)
        elseif at == "flint" then
          args[#args + 1] = numeric(a)
        elseif at == "dict" then
          args[#args + 1] = as_dict(a)
        else
          args[#args + 1] = emit_expr(a)
        end
      end
      return "krt." .. e.rt .. "(" .. table.concat(args, ", ") .. ")"
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
      if op == "<" then return cmp("<", e.a, e.b) end
      if op == "<=" then return cmp("<=", e.a, e.b) end
      if op == ">" then return cmp(">", e.a, e.b) end
      if op == ">=" then return cmp(">=", e.a, e.b) end
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
          if prev_node.t == "any" or rhs_node.t == "any" then
            local fn = ({ ["<"] = "lt", ["<="] = "le", [">"] = "gt", [">="] = "ge" })[o.op]
            conds[#conds + 1] = "krt." .. fn .. "(" .. l .. ", " .. r .. ")"
            prev = rhs
            prev_node = rhs_node
            goto continue_chain
          end
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
        ::continue_chain::
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
      emit(lua_name(s.name) .. " = " .. checked(s.expr, s.type))

    elseif s.k == "assign" then
      emit(lua_name(s.name) .. " = " .. checked(s.expr, s.type))

    elseif s.k == "compound" then
      local v = lua_name(s.name)
      local lhs = s.nullable and ("krt.as_flint(" .. v .. ")") or v
      local rhs = numeric(s.expr)
      local op = s.op
      local expr
      if op == "+" then expr = lhs .. " + " .. rhs
      elseif op == "-" then expr = lhs .. " - " .. rhs
      elseif op == "*" then expr = lhs .. " * " .. rhs
      elseif op == "/" then expr = "krt.div(" .. lhs .. ", " .. rhs .. ")"
      elseif op == "//" then expr = "krt.idiv(" .. lhs .. ", " .. rhs .. ")"
      elseif op == "%" then expr = "krt.mod(" .. lhs .. ", " .. rhs .. ")"
      elseif op == "**" then expr = "krt.pow(" .. lhs .. ", " .. rhs .. ")"
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

    elseif s.k == "for_in" then
      loop_id = loop_id + 1
      local id = loop_id
      local cont = "__continue_" .. id
      local brk = "__break_" .. id
      local coll = "__coll_" .. id
      local idx = "__i_" .. id

      emit("do")
      indent = indent + 1

      local list_mode = s.coll.t == "list" or (s.coll.t == "any" and #s.names == 1)
      if list_mode then
        emit("local " .. coll .. " = " .. as_list(s.coll))
        emit("local " .. idx .. " = 0")
        emit("while " .. idx .. " < #" .. coll .. " do")
        indent = indent + 1
        local v = lua_name(s.names[1])
        emit("local " .. v .. " = " .. coll .. "[" .. idx .. " + 1]")
      else
        emit("local " .. coll .. " = " .. as_dict(s.coll))
        emit("local " .. idx .. " = 0")
        emit("while " .. idx .. " < #" .. coll .. ".keys do")
        indent = indent + 1
        local vk = lua_name(s.names[1])
        local vv = lua_name(s.names[2])
        emit("local " .. vk .. " = " .. coll .. ".keys[" .. idx .. " + 1]")
        emit("local " .. vv .. " = " .. coll .. ".vals[" .. idx .. " + 1]")
      end

      loop_stack[#loop_stack + 1] = { cont = cont, brk = brk }
      emit_stmts(s.body)
      emit("::" .. cont .. "::")
      emit(idx .. " = " .. idx .. " + 1")
      loop_stack[#loop_stack] = nil

      indent = indent - 1
      emit("end")
      indent = indent - 1
      emit("end")
      emit("::" .. brk .. "::")

    elseif s.k == "return" then
      if s.expr then
        if s.expr.t == "any" and current_ret and current_ret ~= "any" then
          emit("return " .. checked(s.expr, current_ret))
        else
          emit("return " .. emit_expr(s.expr))
        end
      else
        emit("return krt.NONE")
      end

    elseif s.k == "func" then
      local params = {}
      for _, p in ipairs(s.params) do params[#params + 1] = lua_name(p.name) end
      emit("local function " .. lua_func(s.name) .. "(" .. table.concat(params, ", ") .. ")")
      indent = indent + 1
      local saved_ret = current_ret
      current_ret = s.ret
      emit_hoist(collect_scope(s.body))
      emit_stmts(s.body)
      current_ret = saved_ret
      if not (s.body[#s.body] and s.body[#s.body].k == "return") then
        emit("return krt.NONE")
      end
      indent = indent - 1
      emit("end")

    else
      error("codegen: unknown statement " .. tostring(s.k))
    end
  end

  emit_stmts = function(stmts)
    for i, s in ipairs(stmts) do
      -- return в Lua обязан быть последним в блоке; если после него есть
      -- стейтменты, оборачиваем в do ... end.
      if s.k == "return" and i < #stmts then
        emit("do")
        indent = indent + 1
        emit_stmt(s)
        indent = indent - 1
        emit("end")
      else
        emit_stmt(s)
      end
    end
  end

  -- ---------- шапка ----------

  emit("-- generated by kraft")
  emit("local __KRAFT_SOURCE = " .. lua_str(opts.path))
  emit("local krt = (function()")
  emit(opts.krt)
  emit("end)()")
  emit("krt.run(function()")
  indent = 1

  emit_hoist(collect_scope(ast.stmts))

  emit_stmts(ast.stmts)

  indent = 0
  emit("end)")
  return table.concat(out, "\n") .. "\n"
end

return codegen
