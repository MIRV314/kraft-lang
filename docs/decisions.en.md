# Language and implementation decisions

> English translation of [the Russian original](decisions.md). In case of disagreement, the Russian version is authoritative.

This file is the source of truth for the compiler. The README explains the language
to the programmer; here is what exactly is considered correct. If the README and this
file disagree, this file is right (and the README must be fixed).

Paths in older entries are historical: since v0.2.0 the service files (`kraft`,
`src/`, `tests/`, `xkraft.kraft`, `Makefile`) live in `dev/`, and the finished
binary is at the root and in `dist/`. The installed `xkraft` and `kraft` are one
and the same x-binary.

Terminology: `kraft` (also `xkraft` and the alias `kraft`) is the main
binary of the current version. `dev/kraft` is always called "frozen `kraft`
v0.1": it serves only to build `xkraft.kraft` and does not change. Where older
entries say "kraft v0.1", they mean exactly `dev/kraft`.

## Language

**D0. Name.** The early variant was `craft`; replacing the first letter produced `Kraft`.
The name is not descriptive and does not reflect the purpose of the language.

**D1. Static typing.** A variable's type is set by its declaration and does
not change. `flint` is one numeric type (a double internally): integers and fractions are not
distinguished. There are no implicit conversions between numbers and collections; the
`str → flint` rule is described in D99.

**D2. `NONE` is an ordinary value.** It can be written in code and assigned
to a variable of any type. It is not a "broken type" but an empty value.

**D3. Operations on `NONE` fail at runtime.** `NONE + 1` →
`TYPE_MISMATCH_ERROR`. Reassign a number — and the variable is normal again.
Exceptions: `==`, `!=`, `is NONE`, `show`, assignment, `return:`.

**D4. Fully static except for reading from a collection without a type parameter.**
`list`/`dict` without a parameter can store different types; reading from them
is checked at runtime. `list[flint]`/`dict[str|flint]` close the hole.
There is no `any` type in the language — only an internal compiler marker.

## Functions and return

**D5. `-> тип` is optional.**
- with an annotation it is a contract, and every `return` is checked;
- without an annotation the type is inferred: all `return expr` must yield one type;
- `return:` (empty) is compatible with any type but marks "may be NONE";
- no `return` at all — the function has type `NONE`.

**D6. Different types in `return` without an annotation are a compile error**, not
an "unknown type".

**D7. Recursion without `->` is an error:** the type cannot be inferred from itself.

**D8. `-> NONE` is not written.** An empty return is the absence of `->`.

**D9. Return annotations:** `-> flint`, `-> str`, `-> bool`, `-> list`,
`-> list[flint]`, `-> dict`, `-> dict[str|flint]`.

**D10. `--types` is not in v0.1.** Debug output of signatures is postponed.

## Scope

**D11. The scope is the function.** A declaration is visible from the point of declaration to the end
of the function, even if it is inside `if`/`while`. If the block did not execute,
the value is `NONE`.

**D12. Redeclaring in the same function — `REDECLARE_ERROR`.**

**D13. Declare before `if`.** Two declarations of the same name in `if` and `else` are
an error. That is the price of the simple scope model.

**D14. A `for` variable is for the loop only.** It is not visible after the loop, does not
shadow an outer name, and cannot be declared a second time in the same
function. `for i` twice — `REDECLARE_ERROR`.

**D15. `for I 5:`** — an all-caps name means a constant, and the loop assigns to it →
`CONST_ERROR`. No separate rule is needed.

**D16. `break`/`continue` only inside a loop, `return` only inside a function.**

## Statements

**D17. Arithmetic as in Python.** `/` is true division (`7 / 2` → `3.5`);
`//` is floor (`-7 // 2` → `-4`); `%` takes the sign of the divisor (`-7 % 3` → `2`);
`**` associates to the right (`2 ** 3 ** 2` → `512`); `*` is multiplication.

**D18. Division by 0 → `VALUE_ERROR`.** A negative power with a fractional
exponent → `VALUE_ERROR`.

**D19. `+` with a string → `CONCATENATE_NOT_SUPPORT` at compile time.**

**D20. Comparisons.** `==`/`!=` — any types: different types yield `FALSE`,
`NONE == NONE` — `TRUE`. `< <= > >=` — only `flint`-`flint` and
`str`-`str` (byte by byte), otherwise an error.

**D21. Comparison chains** (`0 <= x <= 10`) expand into `AND`; the middle
operand is evaluated **once** (via a temporary variable).

**D22. `AND`/`OR` are lazy, the result is `bool`, operands are checked for
truthiness.** `NOT` yields `bool`.

**D23. Truthiness:** only `NONE` and `FALSE` are false; `0`, `""`, `[]`, `{}` are
true.

## Strings and interpolation

**D24. `{}` is the only interpolation.** `$` is an ordinary character.
It works both in string literals and in `show`/`show_err`/`input` templates.

**D25. Rules for `{}`:**
- `{выражение}` — substitution; inside it is an ordinary expression;
- everything outside `{}` is text: `show({x} + 1)` → `5 + 1`;
- `\{` and `\}` are literal braces; `}` outside a substitution is an error;
- an empty substitution `{}` — `SYNTAX_ERROR`;
- nested `{}` inside an expression is a dictionary literal: `show({ {a: 1} })`.

**D26. In `show(...)` templates the parentheses `(` and `)` are call syntax**, so
they are escaped in template text: `show(a \(b\))` → `a (b)`.

**D27. Escape sequences:** `\\ \" \' \n \t \r \e \{ \}`. Inside
`"..."` the double quote is escaped, inside `'...'` the single quote; a "foreign"
quote is not escaped.

**D28. Printing values:** `str` at the top level without quotes, inside
collections in quotes; an integer without `.0`, otherwise up to 14 significant digits;
`TRUE`/`FALSE`; `NONE`; `[a, b]`; `{k: v}`.

**D29. `show`/`show_err` return `NONE`, `input` returns `str`.**

## Collections

**D30. `s[i]` is a one-character string.** Indices are in UTF-8 characters.
A negative index counts from the end. Out of bounds → `VALUE_ERROR`.

**D31. Slices:** the right bound is exclusive, open bounds, negative values,
a step. A reversed range is empty. A step of `0` in a slice → `VALUE_ERROR`; a step of `0`
in `for` → an empty loop.

**D32. A dictionary key in `[]`** is only a bare name or a string literal.
A key variable goes through `take(k)`. Otherwise `TYPE_ERROR`.

**D33. `list[T]`/`dict[K|V]`:** literal contents are checked at
compile time; `add`/`set`/`insert` at compile time if the argument is known
statically, otherwise at runtime.

## Errors

**D34. `TYPE_ERROR` — compile time, `TYPE_MISMATCH_ERROR` — runtime.**

**D35. Errors with a caret and `expected/found`.** Runtime errors also have a
caret: source lines and a "Lua line → Kraft line" map are embedded
in the generated Lua. The position is taken from the stack and points to the start
of the expression in which the error occurred.

**D36. Colors only on a TTY stderr.** Columns are in UTF-8 characters.

## CLI and runtime

**D37. User CLI:** `./kraft file.kraft [args...]` — run.
`./kraft -c file.kraft` — build a self-contained `.lua` next to the source
(without running it). A hidden development flag: `--emit-lua` — print Lua.

**D38. The generated `.lua` is self-contained:** `krt` is embedded, the shebang
`#!/usr/bin/env luajit`, source lines are embedded — runtime errors work
without the source file too.

**D39. `args()[0]` is the path to the `.kraft` source**, followed by the program's
arguments.

**D40. At runtime `NONE` is the sentinel `krt.NONE`, not `nil`.**

**D41. `dict` preserves insertion order:** `{keys = {...}, vals = {...}}`.

**D42. Name mangling:** variables `v_N` in declaration order, functions
`f_N` in declaration order. Cyrillic in variable names is allowed.

**D43. `continue` → `goto` (LuaJIT 2.1).** Locals are hoisted to the start of the
function, and the `for` variable has its own `local` inside the loop.

**D44. `is_tty()` is FFI `isatty(2)`**, the only LuaJIT-specific
place.

**D45. `time_ms()` is `os.clock() * 1000`** (CPU time).

## Core and std

**D46. Core:** `show`, `show_err`, `input`, `type`, `str`, `flint`, `len`,
`read_file`, `write_file`, `file_exists`, `args`, `exit`, `time_ms`,
`is_tty`, `up`, `low`, `title`, type methods.

**D47. Std in Kraft (v0.2, via imports):** `min`, `max`, `sum`, `avg`,
`upk`, `sort`, `reverse`, `clear`, `map`, `filter`, `reduce`, `assert`,
`expect`.

**D48. `system` is v0.2**, std and xkraft do not need it: launching is done by the
`kraft` wrapper.

**D49. Imports (`import_file`/`from_file`) are v0.2, before std.**

## Constants

**D50. A constant is a name without lowercase Latin letters** (`MAX`, `MAX_SIZE`,
`X`). Assignment → `CONST_ERROR`.

## Functions

**D51. A function is visible after its declaration.** Calling before declaration — `NAME_ERROR`.
A function sees its own name from the start of the body: recursion works. If there is no `->`,
it cannot call itself — `TYPE_ERROR` ("an explicit `->` is needed"), because the return
type has not been inferred yet.

**D52. A function body is a separate scope.** Only parameters and
locals are visible; file variables are not (`NAME_ERROR`). Top-level
functions can be called. Declarations inside the body are hoisted to the start of **this**
function, not the program.

**D53. A possible "fall-through" of the body.** If the body does not end with `return`,
the function may return `NONE`; its result is marked "may be NONE", and
operations on it are checked at runtime. The same holds for `return:` and
`return NONE` with an explicit `->`.

## Strings: indices, slices, methods

**D54. `s[i]` and slices are in UTF-8 characters.** Indexing is 0-based, a negative
index counts from the end, out of bounds — `VALUE_ERROR`. A slice `s[a..b]`: the right
bound is exclusive, bounds may be open (`s[..b]`, `s[a..]`),
negative indices are normalized, bounds are clamped to the range.
A step of `0` — `VALUE_ERROR`; a positive step with `a > b` and a negative one with
`a < b` yield an empty string. `s[3..1..-1]` is reverse order. The step must
be an integer (`VALUE_ERROR`), otherwise indices become fractional.

**D55. String methods** (0-based, indices in characters):
`part(a, b?)` — substring `a..b` (without `b` — to the end);
`find(sub)` — index of the first occurrence or `NONE`;
`contains(sub)` — `bool`;
`preff(p)` / `suff(p)` — starts/ends with `p`;
`trim()` / `triml()` / `trimr()` — remove whitespace;
`replace(old, new)` — replace all occurrences;
`count(sub)` — number of non-overlapping occurrences (`""` → `0`).
`find` is marked "may be NONE"; an empty substring in `replace` changes
nothing.

## Collections without a type parameter

**D56. `list` and `dict` without a parameter are dynamic.** They store values
of any type. Reading (`xs[i]`, `d[k]`, `take`) has the internal type `any`:
it is compatible with any type in declarations, assignments, passing to
a function, and `return`, while an operation that needs a concrete type is checked
at runtime (`TYPE_MISMATCH_ERROR`). An index, a slice, and `for-in` over `any`
choose the type at runtime: `for x in v` is a list, `for k, v in v` is a dictionary.
A method cannot be called on `any`: first bind the value to a type
(`list row = xs[0]`), then call `row.add(...)`. `is` looks at the
actual type of the value. `list[flint]` / `dict[str|flint]` — after v0.1.

**D57. Literals.** `[a, b, c]` is a list, `{}` is an empty dictionary,
`{ключ: значение}` is a dictionary. A key is a bare name or a string literal without
interpolation; `user[имя]` and `user["имя"]` are one key `"имя"`. Pair order
is preserved. A repeated key replaces the value without changing the position.

**D58. List indices and slices** are like strings (D54): 0-based, negative from
the end, out of bounds — `VALUE_ERROR`. A slice returns a new list; a step of `0` —
`VALUE_ERROR`; the step must be an integer (D54); an empty range is an empty
list.

**D59. Reading a dictionary.** `d[ключ]` and `d.take(ключ)` return the value or
`NONE` if the key is absent (not an error). A key is always `str`; a dynamic key
(a variable, an expression) is passed only to methods. Methods: `add(k, v)`,
`take(k)`, `remove(k)` → `bool`, `contains(k)` → `bool`,
`merge(other)` — the pairs of `other` overwrite matching keys.

**D60. List methods.** `add(v)` — append; `del(i)` — by index
(`VALUE_ERROR` out of bounds); `remove(v)` → `bool`, removes the first
occurrence; `replace(i, v)`; `contains(v)` / `count(v)`; `index(v)` — the index
or `NONE`; `join(sep)` — elements via `str`, separator `str`.

**D61. `for ... in`.** Over a list — one variable (elements), over a dictionary —
two (key, value) in insertion order. The collection is evaluated once.
Variable names follow D14: `for x` twice in the same function —
`REDECLARE_ERROR`.

**D62. Collections are by reference.** Assignment, passing to a function, and `for-in`
do not copy a list/dictionary: a change through one variable is visible through
another. `==`/`!=` compare references (the same collection — `TRUE`).

## Built-in functions

**D63. Conversions.** `len(x)` — `str` (UTF-8 characters), `list`
(elements) or `dict` (keys). `type(x)` — the type name as text. `str(x)` —
printing the value as at the top level. `flint(x)`: a number as is,
`bool` → 1/0, `str` → parsing (`"abc"` → `VALUE_ERROR`), everything else —
`TYPE_MISMATCH_ERROR`.

**D64. Files.** `read_file(path)` returns the whole file as `str`; no
file — `FILE_ERROR`. `write_file(path, text)` overwrites the file entirely
and returns `bool`; a write error — `FILE_ERROR`. `file_exists(path)` →
`bool`.

**D65. Process.** `args()` → `list[str]`, `[0]` is the path to the source (D39).
`exit(code)` terminates the program. `time_ms()` is `os.clock() * 1000`.
`is_tty()` is `isatty(2)` (D44). Built-in function names are reserved:
declaring a variable, function, parameter, or loop variable with such a
name — `NAME_ERROR`.

## Input for tests

**D66. `# stdin: текст`.** A comment line with this prefix (indentation
is allowed) defines a line of built-in input. `input()` reads such lines
in order, then real stdin. Spaces after `:` are the separator, an empty
tail is an empty string. The lines are embedded into the generated Lua, so they
work with `-c` too.

## The compiler in Kraft itself

**D67. `xkraft`.** A compiler written in frozen v0.1 that
compiles itself. The lexer, the parser with static checks, and the
code generator live in a single file `xkraft.kraft`; mutual recursion
is forbidden, so each recursive procedure calls only itself.
The interface matches the reference `kraft`: `--tokens`, `-c`, otherwise Lua to
stdout; xkraft does not run `luajit` itself (D48). The runtime is found as
`dirname(args()[0]) .. "/src/krt.lua"`. The reference compiler on LuaJIT
is frozen at tag `v0.1.0` and serves as a check: on compatible tests the output of
xkraft matches it byte for byte. Cases forbidden by the new rules
(D77, D81) intentionally differ: `./kraft` remains the v0.1 compiler.

**D68. Small core, growth through libraries.** The v0.1 language core is frozen.
New features do not add *new* keywords or types: the words from
"In development" are already reserved in v0.1. Library features
appear as a prelude in Kraft without `import` (D80). An exception was made for
error handling: `try`/`trigger`/`finally` are implemented in the core of `xkraft`
(D82), because catching runtime errors cannot be moved into a library.
`panic` and `froz` are implemented in D85 and D83; imports remain reserved
and unimplemented.

## The language after v0.1

**D69. Block type declaration.** `str:`, `flint:`, `bool:`, `list:`,
`dict:` open a block in which each line is a declaration
`имя = выражение` with that type. `froz:` will be added later; models do not
participate in such blocks. The usual naming rules apply: all-caps constants,
occupied names, redeclaration. A type block is only compact
notation, not a scope: names are visible to the end of the function/file, like
ordinary declarations. Blocks can be written at the top level and inside
functions/blocks; nested type blocks are not needed.

**D70. Global variables.** The top level of a file is the global scope.
A function reads and writes globals directly by name: `ext` has been removed from the language
and from the keyword table; the word is free for future features (e.g.
model inheritance). Local declarations, parameters, and `for` variables
cannot coincide with global names — `REDECLARE_ERROR`, so writing
to a global from a function is unambiguous without a marker. A constant global
(an all-caps name) can be read, but writing to it — `CONST_ERROR`. Visibility
of globals in functions replaces the rule "a function sees only parameters and
locals" from D51–D53; declaration order, the ban on mutual recursion, and
an explicit `->` for recursion are preserved.

**D71. Indexed assignment.** `xs[i] = v`, `d[ключ] = v` (the key is a bare
name or a string literal), `xs[i][j] = v`. A list index is `flint`,
a negative one counts from the end, out of bounds — `VALUE_ERROR`. A string
is immutable: `s[0] = "x"` — `TYPE_ERROR`. For a value of type `any` the check is
at runtime. Compound `+=` on indices is not added. `list.replace(i, v)`
remains replacement by index (needed for bootstrapping `xkraft`); replacing a
value is `replace_value(a, b)`.

**D72. The full set of built-ins is the core.** Everything from `docs/builtins.md`
is available without libraries: strings (`up`, `low`, `title`), numbers (`abs`,
`round`, `floor`, `ceil`, `sqrt`, `min`, `max`), collections (`sum`, `avg`,
`keys`, `values`, `upk`, `sort`, `reverse`, `clear`), files, the process
(`system`), tests (`assert`, `expect`), higher-order functions (`map`,
`filter`, `reduce`). D68 is clarified: the core includes the full set of built-ins,
stdlib is only optional add-ons. Key decisions:
`find` → `NONE`; `part` is split as in Python, a substring is a slice;
`remove` removes all occurrences (with an optional count); `merge`
returns a new dictionary; `sort`/`reverse` return new lists;
`clear` changes in place; `round` rounds halves away from zero; `sqrt` of
a negative number and `avg` of an empty list — `VALUE_ERROR`; `min`/`max` take from 1
to 9 arguments or one list.

**D73. Functions as arguments.** `map`/`filter`/`reduce` take a function
by name, without lambdas: `map(xs, double)`. This is the only place where a function
name is used as a value; user-defined functions do not yet have parameters of type `func`.
The arity of `f` is checked at compile time: 1 for
`map`/`filter`, 2 for `reduce`.

**D74. `assert` and `expect`.** `assert(condition, message)` with a false
condition throws `ASSERT_ERROR` with the text. `expect(value)` returns
the internal type `expect` with methods `equals`, `is_true`, `is_false`,
`is_none`, `contains`; failure — `EXPECT_ERROR`, success — `NONE`.

**D75. Bootstrapping `xkraft`.** The source `xkraft.kraft` remains written
in v0.1 syntax and uses only v0.1 built-ins so that the frozen
reference compiler can build it. New features are implemented by `xkraft`
for compiled programs; `xkraft.kraft` itself does not use them. Therefore,
in particular, `list.replace(i, v)` keeps the meaning of replacement by index.

**D77. The top level is declarations only.** In `xkraft` the new rules
are always on: there is no separate directive, mode, or opt-out. A global
cannot be reassigned on a direct top-level line: `x = ...` and
`x += ...` produce a compile error `TOPLEVEL_ERROR`, and the program does not
start. A global is a variable declared outside a function. Without
a separate directive, self-hosting is preserved: `xkraft.kraft` is written
so as not to reassign globals at the top level. The frozen
`./kraft` still compiles v0.1; the new model applies to
`./xkraft`. There are no new keywords such as `mut`. Writing to a global is done
by name without `ext`. All-caps names remain hard constants: writing to
them — `CONST_ERROR` anywhere. A separate category `TOPLEVEL_ERROR`
was chosen deliberately: it means "cannot be changed here", whereas
`CONST_ERROR` means "cannot be changed ever". Clarification of the modification zone is
in D81. The old comment line `# const-top` no longer enables anything
and can be removed from programs.

**D78. Cache of the compiled `xkraft`.** The `xkraft` wrapper builds
`xkraft.kraft` into `xkraft.lua` once and rebuilds only if
`xkraft.kraft` or `src/krt.lua` is newer. The reason: compiling the compiler on
every run cost ~100 ms and dwarfed the actual program time
(10 million loop iterations — ~12–20 ms, the whole command with cache — ~30 ms).

**D79. Occupied names — including methods.** All built-in functions, keywords,
types, `TRUE/FALSE/NONE`, `Error`, as well as `error` and `ANY_ERROR` and
**the names of methods of all types** (`add`, `del`, `take`, `contains`, `count`,
`join`, `part`, `trim`, `equals`, `text`, etc.) form one common list
of occupied names. Any
declaration — a variable, parameter, function, model, field, or method — with
such a name produces `NAME_ERROR` already at compile time. Previously methods were not
checked: `flint add = 1` and `func add(...)` compiled, although `add`
already means a list and dictionary method. Now a name is unambiguous everywhere, and
the standard library can be extended without fear of collisions.

**D80. Std library without modules.** The standard library is a prelude in Kraft
itself: `dev/prelude.kraft` compiles into `dev/src/prelude.lua`, and the compiler
adds its functions to every program without `import`. The user calls
`path_join`, `now_ms`, `parse_args`, `parse_csv`, `parse_json`, `prelude_cat`
directly. Reasons: the goal is a single command, there are no modules in the core, and name rights
are already reserved by D79. The prelude is enabled by default; `--no-prelude`
removes both the function declarations and the code from generation. In `dist/xkraft` the prelude Lua
is embedded, as is the runtime.

**D81. A condition does not open a modification zone.** A global variable can be
reassigned only directly in the body of a function or a loop (`for`,
`while`). `if`, `elif`, `else` blocks are not a modification zone:
`x = ...` inside a condition gives `TOPLEVEL_ERROR`, even if the condition itself
is inside a function or loop. The reason: by its place in the source the change
lies in the condition block, while the function or loop is outside. It is implemented
with a `cond_depth` counter that is incremented while parsing each
branch of a condition. A variable declared inside a condition at the top level
is also considered global (D77), so reassigning it there is also
forbidden; for such changes a local is declared in a function. The contents
of ordinary `list` and `dict` are not covered by this rule: they are mutated by
`add`/`del`/`remove`/`replace` everywhere, while `froz` is immutable and does not allow
such changes.
Constants and models are not affected.

**D82. Error handling: `try` / `trigger` / `finally`.** A block consists of exactly
three parts: `try:`, one or more `trigger <КАТЕГОРИЯ>:` branches, and a
mandatory `finally:`. The `ANY_ERROR` branch catches everything else and
must be last; repeating an explicit category — `REDECLARE_ERROR`,
an unknown category — `NAME_ERROR`. In each branch the object
`error` of the model `Error` is available (fields `cat`, `msg`, `file`, `line`, `col`, method
`text()`); the name is reserved, writing to it — `CONST_ERROR`. An error inside
a `trigger` branch is not caught by the same block.

`finally` runs on any outcome: success, a caught error,
an uncaught error, and `return` from the body or a branch. `break`/`continue` cannot
cross the `try` boundary (`SCOPE_ERROR`), because the body of `try` is a
closure wrapper. Implementation: the body and branches run via `pcall`,
success is marked with a unique marker table; after `finally`
an uncaught error is rethrown via `_G.error(err, 0)` so that
`krt.run` prints it in the usual format with the caret preserved. The global
reassignment zone of D81 is not extended by `try`.

**D83. Typed collections and `froz`.** Type parameters in `[]` are optional:
`list xs` remains an ordinary list, while `list[flint] xs`, `froz[flint] fs`, and
`dict[str, flint] d` specify concrete types. `dict[str|flint]` is equivalent to
`dict[str, flint]`: to the left of the separator is the key type (always `str`), to the right —
the value type. Inside the brackets only `str`, `flint`, `bool` are allowed, one type
or several separated by commas. `|` works only as a pair separator in
`dict`; in `list`/`froz` it remains a syntax error. Nesting
(`list[list[str]]`, `froz[list[str]]`), `list[NONE]`, and `dict[flint, str]`
are forbidden (`TYPE_ERROR`). `froz[T]` is a read-only list: reading, indices,
slices, and `for in` work; indexed writing gives `CONST_ERROR`, mutating
methods give `NAME_ERROR`, a slice preserves `froz` and the specification. The specification
is checked at declaration and when adding elements
(`TYPE_MISMATCH_ERROR`).

**D84. Strict falsiness.** In `xkraft` `TRUE` is truthy, `FALSE` and `NONE` are
falsy. `if`/`while` conditions, `NOT`/`AND`/`OR` operands, and the `assert` condition
go through `check_condition`: `bool` or `NONE` is expected. `0`, `""`,
`[]`, `{}` give `TYPE_ERROR` at compile time. The type `any` passes
statically but is checked at runtime via `krt.truthy_strict`. The old
`krt.truthy` is kept for v0.1 and does not change.

**D85. `panic`.** `panic("CATEGORY"[, "message"])` is a statement with category and
message as plain strings. The category must be in the list of known
categories, otherwise `VALUE_ERROR`; without the second argument the message equals
the category. It compiles to `krt.fail(cat, msg)` and is caught by ordinary
`trigger CATEGORY` / `trigger ANY_ERROR`. The `try` syntax is not extended:
grouping branches under a common `trigger:` is postponed until the stage of modules, imports,
and the package manager.

**D86. Windows distribution.** `dist/xkraft-win.lua` is the same embedded Lua code
of the compiler as in `dist/xkraft`, but without the shell/awk wrapper. `xkraft.cmd`
calls it via `luajit`, `kraft.cmd` calls `xkraft.cmd`.
`install-win.cmd` copies the files to `%LOCALAPPDATA%\Programs\kraft` or to
`%KRAFT_BIN%`, adds the directory to the user's `PATH`, and checks
`--version`. The asset is `kraft-win.zip`. LuaJIT is not included in the distribution and is installed
separately.

The following decisions were implemented in `0.4.0`.

**D87. `..` is the range operator.** `..` creates a `range` value with fields `from`, `to`, `step`. There is no separate declaration `range r = ...`: the range is written in place — `1..10..0.5`, `for i 1..5`, `xs[1..3]`, `if age in 0..17`. The right bound is excluded: `1..5` is `1, 2, 3, 4`. A single range parse is used in expressions, function arguments, slices, `for`, and `in`. Bounds are always integers; `1..10.0`, `1.0..10.0`, `1..10.0..0.5` give `TYPE_ERROR`. An empty range (`5..5`) is allowed; `rand_num(5..5)` (since `0.9.1` — `math.random(5..5)`, D120) gives `VALUE_ERROR: empty range`.

**D88. The range mode is set by the form of the step.** For an integer range the step is optional and defaults to `1`: `1..10` and `1..10..1` are the same. For a fractional range the step is mandatory and must be written with a decimal point: `1..10..1.0`, `1..10..0.5`. The bounds remain integers. No new `int`/`float` types are introduced: the numeric type is still one — `flint`; `range` is the type of a range value. `rand_num` uses the step as a grid of values: `rand_num(1..10..0.5)` yields `1.0, 1.5, …, 9.5`. Implemented via `math.random` in `0.9.1` (D120).

**D89. `in` — iteration and membership.** `in` indicates that a variable is iterated over a collection or checked for membership: `for x in list1`, `for k, v in dict`, `if age in 0..17`. For `range`, an `in` check means falling into a half-open interval with the step taken into account. A numeric loop over a range is written without `in`: `for i 1..5:` (schematically `for i r:`); this is a deliberate exception — `in` is reserved for iterating collections and checking membership, not for range-loop syntax.

**D90. Grouping `trigger`.** `trigger CAT1, CAT2:` is one handler for several categories; inside, `error.cat` with the specific category is available. `ANY_ERROR` is written separately: combining it with others or repeating it — `SYNTAX_ERROR`. Repeating a category in different `trigger:` — `REDECLARE_ERROR`.

Decisions implemented in `0.5.0`.

**D91. The ecosystem is in `0.5.0`.** `kpm` and virtual environments (`venv`) are part of `0.5.0`. The canonical command is `kpm init venv`, not `kpm venv init`. It immediately creates `kraft.json`, `kraft.lock`, `venv/`, `packages/`, and a copy of the compiler: on Linux `venv/bin/xkraft`, on Windows `venv/bin/xkraft-win.lua` and `venv/bin/xkraft.cmd`. `kpm run` is the portable way to use this environment: running `main.kraft` through it. The package registry and moderation were planned for `1.0.0`, but by D107 were postponed to a separate later release.

**D92. `dict` keys.** A key is `str` or `flint`. In a literal it is written as a bare name or in quotes: `d[имя]` ≡ `d["имя"]`. `bool`, `NONE`, collections, and models cannot be keys; a value can be of any type, including nested `list`/`dict`. A dynamic key goes through `d.take(k)` and `d.add(k, v)`.

**D93. Import without `export`.** The `export` keyword has been removed. All top-level declarations of a module are available to `import_file`, `from_file`, `import_lib`, and `from_lib`; a `_` prefix does not create privacy. Selecting names is the responsibility of the importing file. Inside `namespace` short names are visible within the namespace itself; from outside, access is via a dot.

**D94. Minimal stdlib.** Only `std/fos` and `std/cli` are embedded in the distribution. `std/fos` ("File Operating System") provides `exists`, `copy`, `remove`, `read_text`, `write_text`, `read_json`, `write_json`, `read_csv`, `write_csv`; `csv_field`, `csv_line`, and `csv_parse` are ordinary top-level names. `std/cli` provides only `run(command)` and `kill(message)`. `std/fs`, `std/json`, `std/file`, `std/math`, universal `read`/`write`, `open`/`close`, `die`, and `tty()` are not added. `json_parse` and `json_stringify` remain internal built-in functions. The item about `std/math` was revised by D120.

**D95. Math in the core.** `fib(n)` and `factorial(n)` are built-in functions of the compiler and runtime, not a stdlib module. In `0.9.0` the constant `PI` was added to the core as a keyword: `show({PI})` prints `3.1415926535898`. An empty `std/math` is not created. `clamp`, `lerp`, and `is_even` are not introduced at all. The built-in `title` remains but is not highlighted in the documentation. The ban on `std/math` was lifted by D120; the ban on `clamp`, `lerp`, and `is_even` is retained.

**D96. The manifest section is called `deps`.** A project is described by the pair `kraft.json` + `kraft.lock`. The dependency section is `deps`, not `requirements` and not `dependencies`; `requirements.txt` is not used. A dependency is given by a local path or URL and is installed into `packages/<name>/`.

**D97. Output and input.** The canonical functions are `show`, `show_err`, and `input`. Aliases `read()`, `ask()`, `echo`, and `$` syntax are not added.

**D98. Boundaries of models.** Before `1.0.0` no inheritance, polymorphism, encapsulation/private fields, properties, `class`, or operator overloading are introduced. Models remain simple: `model`, `construct`, `method`, `self`, `init`.

**D99. String to `flint` without an explicit conversion.** `flint` accepts a string value without calling `flint(...)`: the compiler inserts the conversion if the expression type is `str`. The rule applies in declarations, assignments, arguments, returns, and initial values of model fields. This is how `input()`, `args()`, `read_text()`, and CSV cells work. A numeric string literal is checked at compile time (`flint n = "42"` is allowed, `flint n = "x"` — `TYPE_ERROR`); a non-numeric value from outside gives `TYPE_MISMATCH_ERROR: expected flint, found str: <значение>` at startup. Explicit `flint(x)` and `str(x)` remain. There are no `list()` and `dict()` conversions: creating a collection is parsing a structure (`parse_csv`, `parse_json`, `map`), not a type conversion.

**D100. Updates are in `0.6.0`, done.** In `0.5` the compiler did not access the
network and did not change installed files. The update logic lives in the
`dist/xkraft` wrapper (`dev/update.sh`, embedded at build time), so the Kraft
compiler source and byte-for-byte self-hosting are unaffected. A check for
a new version happens at most once a day, only in a terminal, and only after
a successful request; timeout 15 s, disabled via `KRAFT_NO_UPDATE_CHECK=1`.
`xkraft --update` downloads `xkraft` and `SHA256SUMS` from GitHub Releases, verifies
the hash, and atomically replaces the file; on Windows the files from `kraft-win.zip` are updated.
Network errors are silently ignored during a background check and reported with an explicit
`--update`. An update does not overwrite projects' venvs.

**D101. Basic style in dev, public linter in `0.8.0`, done.**
`docs/style.md` remains the source of the rules. In `0.5` only the
dev script `dev/tests/style.sh` is added: it checks indentation, names, `export`,
forbidden builtins, and trailing whitespace; it is not part of `make check` or `dist`.
Release `0.7` was skipped: both small improvements were combined in `0.8.0`. The public
command `xkraft lint [path...]` checks the same rules, works with files
and directories on Linux and Windows, and is part of `make check`. The formatter and LSP
remain out of scope for `0.8`.

**D102. Fractional range step is in `0.8.0`, done.** Output of values of a fractional
range became `1.0, 1.5, 2.0, …, 9.5` instead of the mix `1, 1.5, 2`. Global printing of
`flint` does not change: `fib(10)` still yields `55`. A range-aware
approach was chosen: the compiler marks the names of Lua variables that came from a range with
a fractional step, and for their output calls `krt.tostr_range_flint`, which
adds `.0` only to integer values. Ordinary numbers and an integer range
are unaffected. There is no explicit `fmt_flint()`.

**D103. LSP is after `1.0`.** In `1.0` only highlighting and snippets for
VS Code remain. The compiler gets stable machine-readable `--diagnostics` and
`--ast-json`, whose format is fixed in the documentation. The language server and
editor clients appear on their basis after the official `1.0`: the grammar is
fixed by the `async` keyword already in `0.9.2` and then stays unchanged until
the next unfreeze (D122). Decorators are not part of the baseline grammar.

**D104. `std/http` is in `1.1`, after async.** After the official `1.0` a
networking library appears: `get(url) → str`, `post(url, body) → str`,
`download(url, path) → bool`, and `get_many(urls) → list[str]`. The implementation is
a thin wrapper over `curl` with timeouts; on Windows — `Invoke-WebRequest`. Errors
get the category `HTTP_ERROR`. The module is embedded in the distribution, like
`fos`, `cli`, `math` and `base`. Calls are suspendable: inside an `async` function
they yield to the event loop, outside `async` they are synchronous; `get_many`
runs requests in parallel on the async machine already shipped in `0.9.2`. D94
is extended: the public API becomes `std/fos`, `std/cli`, `std/math`, `std/base`,
`std/http`.

**D105. Decorators are an idea with no deadline, not in `1.x`.** The previous
plan (`deco`, `@name`, `target()` in `1.2`) is canceled by D122: decorators are
not in `0.9.2`, not in `1.0`, not in later `1.x`, and are not put into `std/base`.
The idea is kept only as a sketch for a future grammar unfreeze: `deco log():`
would define a wrapper body, `target()` inside it would mark the call of the
original function, `@name` would be equivalent to `@name()`, and an explicit
`return` would change the result. It would be pure compile-time expansion, but
there is currently no plan to implement it.

**D106. `async` and auto-await are in `0.9.2`.** A declaration `async name(args): ...`
takes the place of `func`; `async` becomes a reserved name. Calling
an async function starts the work immediately and returns a future that statically
has the result type. The compiler inserts a wait at the first use of the
value (scheme with a test suspension point):

```kraft
async work(flint x) -> flint:
    return timer(10, x)   # test suspendable operation

flint a = work(1)   # the first job has already started
flint b = work(2)   # and so has the second
show(a + b)         # both results are awaited here
```

Thus the syntax "just `async ...` and nothing else" gives parallelism without an explicit
`await`. In `0.9.2` timers and test futures are suspended; starting with `1.1`
`std/http` calls are added (D104). Files, `input()` and `system()` remain blocking.
An event loop in `krt.lua` and an update of the VS Code grammar are needed. A future's
error is raised at the point of waiting. From the official `1.0` on, the grammar is
frozen: no new syntax until the next unfreeze (D122).

**D107. `0.9.0` and the postponed ecosystem.** The nearest release is `0.9.0`: `PI`
is added to the core as a built-in constant alongside `fib`/`factorial`;
`std/math` is not created, `clamp`, `lerp`, and `is_even` are not introduced. In `0.9.0`
the `kpm` fixes already in `main` (XOR and `os.execute`) and CI also
land. The site, package registry, AUR package, and example showcase planned for `1.0`
(D91) are postponed to a separate later release; their exact number will be
chosen separately. The part of D91 about the registry in `1.0.0` is considered postponed.

**D108. The core / std boundary.** Only what cannot be written in Kraft goes
into the binary: new syntax, a new type or semantics, or something the compiler
itself needs. Everything expressible in Kraft lives in std. An idea without example code
does not become a decision. The current `model`, `construct`, `method`, `self`, and
`init` remain in the core. Future principles such as inheritance and polymorphism
are laid into std as patterns over `model`/`dict`/`self`, not as language-level
OOP; a real `class` and subtyping will require a separate core decision.
`async`/auto-await was added to the core in `0.9.2`: it is new syntax and
semantics, so it cannot be a library. Decorators, `fn` lambdas and multiline
`show()` do not enter the core and remain ideas with no deadline (D105, D115,
D123).

**D109. `..`, `show()`, and `input()`.** D87/D88 already define `..` as an operator
for a range value, including in function arguments. A separate declaration
`range r` is not required and is not introduced: `gen_list(10..101)` and
`gen_list(1..10..0.5)` are ordinary calls where the function takes a range and works
with `from`, `to`, and `step` itself. No new sugar or new type is needed; canceling
D87/D88 is not planned. In `show()` and `input()` the argument is a template, not a
string literal: the text is written without quotes, and `..` inside it is just two
characters. A quote in a template is obtained via a variable:

```kraft
str q = "\""
show({q}..{q})
```

`$` holes in signatures (`$(flint x)`) and macros are not introduced: the
`gen_list` task is covered by the already existing range from D87.

**D110. `std/base` is one module in `1.0`.** The "idea without a date" plan
is canceled: the module is embedded in the distribution together with the
official `1.0`, like `std/math`, with no subdirectory modules. Contents:
`tern(cond, a, b)` — an ordinary function with eager evaluation of both branches;
string helpers over `up`/`low`/`part`/`suff`/`preff`/`find`; `render(...)` as a
function over `dict`, without `$` in the grammar; patterns over
`model`/`dict`/`self`, including the OOP patterns from D123. A lazy ternary
`if ... else` remains a core candidate. Decorators and multiline `show()` are not
put into `std/base` (D105, D123). A separate module is created only when 5+
functions accumulate in one topic. The module was built early and already ships
in `0.9.2`, before the official `1.0`.

**D111. `method.type` is an idea without a date.** It is added neither to the core nor to std.
The thought: outside a model, write `method.str name(...)` or `method.flint name(...)`,
so that `s.name()` works as it does for models; `self` inside would be a value of that
type. A sketch of the restrictions: only `str` and `flint`, a conflict with a built-in or
another user method — `REDECLARE_ERROR`. The reason we are not doing it now:
a helper function with a large number of arguments looks
unnatural, and core sugar is not needed yet. If the idea returns, it will be
sugar in the binary, not std.

**D112. `iinput()` is an idea without a date.** It is added neither to the core nor to std/base.
The thought: a call without arguments, the prompt is taken from the variable name:
`flint age = iinput()` → in the terminal `age: `. Such behavior would require
core sugar; for now the idea remains just a thought, as does `method.type`.

**D113. `upk` without commas.** Planned output: the separator is a space, commas
are removed: `[1, "два"]` → `1 "два"`, `{name: "Kraft"}` → `name "Kraft"`. The date
is separate, not in `0.9.0`; until implementation `docs/builtins.md` describes the current
output with commas.

**D114. `_` / `__` is a convention, not privacy.** The prefix hints to the
reader that a name or field is "internal", but the compiler does not hide it and does not
complain about access: `obj._x` works. There is no language-level encapsulation; patterns
with such names live in std.

**D115. Lambdas: `fn`, if ever.** There are no lambdas now; functions are passed
by name. If the idea returns, the keyword is `fn`, not `lambda`; the date is separate.

**D116. Installation and updating in `1.0`.** Both POSIX installers — `install.sh`
and `install-auto.sh` — put `xkraft`, `kpm`, and the alias
`kraft` into the command directory; the frozen `kraft` v0.1 is not installed into the system. In the AUR package the alias
`kraft` is not created. `kpm --version` shows `1.0.0`. The only update command
is `kraft --update` (the same as `xkraft --update`): it updates both
the binary and `kpm`. `kpm update` and `kpm --update` have been removed; `kpm` replies that
updating is done via `kraft --update`. The update logic lives only in
`dev/update.sh` and is embedded into `dist/xkraft`; there is no Lua duplicate in `kpm.lua`.
The script downloads `SHA256SUMS`, `xkraft`, and `kpm`, verifies **both** hashes before any
replacement, and only after successful verification replaces both files. `kpm` is updated
only if it already sits next to the binary. On Windows `kraft --update`
unpacks `kraft-win.zip` with `xkraft-win.lua` and `kpm-win.lua`. Replacement goes
through a copy to a temporary file next to the target and `rename`: a direct `mv` from the
download directory breaks on a different filesystem. For tests and mirrors,
`KRAFT_UPDATE_DOWNLOAD` (the old name `KPM_UPDATE_DOWNLOAD` is also accepted),
`KRAFT_UPDATE_API`, `KRAFT_NO_UPDATE_CHECK`, `KRAFT_UPDATE_CACHE`, `XKRAFT`, and
`TMPDIR` work. The variable `KPM_SELF` no longer exists.

**D117. `..` and `...` in slices.** `..` is the bound separator, `...` is the step
separator; this is consistent with ranges in `for`, where the step is also separated by `..`. Correspondence
with Python: `..` ↔ `:`, `...` ↔ `::`. The forms for `xs = [10, 20, 30, 40, 50]`:

| Notation | Meaning | Result |
| --- | --- | --- |
| `xs[..2]` | from the start up to index 2, exclusive | `[10, 20]` |
| `xs[a..b]` | from `a` to `b`, exclusive | as before |
| `xs[a..]` | from `a` to the end, step 1 | `[30, 40, 50]` |
| `xs[..]` | a copy of everything | `[10, 20, 30, 40, 50]` |
| `xs[a...step]` | from `a` to the end with step `step` | `xs[2...3]` → `[30]` |
| `xs[a...]` | same as `xs[a..]`, sugar for `a::` | `[30, 40, 50]` |
| `xs[...step]` | the whole list with step `step` | `xs[...2]` → `[10, 30, 50]` |
| `xs[...]` | same as `xs[..]` | a copy of everything |
| `xs[a..b..step]` | from `a` to `b` with step `step` | as before |

A negative step works (`xs[4...-2]` → `[50, 30, 10]`); a step of `0` —
`VALUE_ERROR`. Loops keep only `for i b`, `for i a..b`, and
`for i a..b..step`: `for` has no implicit right bound, so `...` forms
of loops are not introduced. The lexer distinguishes `...` as a separate op3 before parsing `..`.
The runtime is ready: `nil` bounds already mean "from the start / to the end". The new syntax is
implemented in `dev/xkraft.kraft`; `dev/xkraft.kraft` does not use it in its own
body, so the frozen `kraft` v0.1 still builds it.

**D118. `pass` is an empty statement.** The keyword `pass` is allowed wherever
a statement is expected and does nothing. It is needed so that an `if`/`else` branch or a loop
body can be empty without a placeholder comment. In Lua it is emitted as
`do end` — a real no-op that keeps the block non-empty. Added in
`dev/xkraft.kraft`, not used in the compiler's body.

**D119. Result of the core/std audit before `1.0`.** Nothing is moved out of the core, and there are no new
std modules. The core keeps `len`, `type`, `str`, `flint`; `up`, `low`,
`title`; `abs`, `round`, `floor`, `ceil`, `sqrt`, `factorial`, `fib`, `min`,
`max`; `sum`, `avg`, `keys`, `values`, `upk`, `sort`, `reverse`, `clear`;
`map`, `filter`, `reduce`; `read_file`, `write_file`, `file_exists`; `args`,
`exit`, `time_ms`, `is_tty`, `system`; `assert`, `expect`; `show`, `show_err`,
`input`; `PI`, string/list/dictionary methods and indices. The prelude is enabled
automatically and disabled with `--no-prelude`. std is only `std/fos` and
`std/cli`; `copy_file`, `remove_file`, `json_parse`, `json_stringify`, `raise`,
`glob` are reserved non-public names. `title` was kept in the core after
checking its UTF-8 semantics; it had been proposed to move it out — the proposal was withdrawn.
The number group stays entirely in the core. `keys`/`values` are not moved out: `upk` is a string for
interpolation, not a combined accessor; there is no dictionary iteration in the language, and moving them out would require
a new primitive. `map`/`filter`/`reduce` are core by D73:
user functions cannot have a parameter of type `func`. `system`,
`assert`, and `expect` are core by explicit choice. `PI`, `fib`, and `factorial`
are fixed; `std/math` was introduced by D120, `clamp`, `lerp`, `is_even` are not introduced. `upk`
remains a string; the idea of D113 (a space instead of commas) has no date. `class` is not
introduced: the role is filled by `model`, OOP patterns are in std. Lambdas, if they appear,
only `fn`; `method.type` (D111) and `iinput()` (D112) are ideas without a date.

**D120. `std/math` in `0.9.1`.** The part of D94/D95/D119 that forbade `std/math`
was canceled: a third std module is embedded in the distribution. It provides only `pow(a, b)` and
`random(x)`. `pow` is a name for the already existing `**` operator; no new primitive
is introduced. `random(x)` dispatches on the type of the argument: for `range` the
reserved built-in function `rand_num` is called, for a list — `rand_choice`.
Both primitive functions remain non-public: user code calls them
through `std/math`. The `range` semantics fully inherit D87/D88: the right
bound is excluded, the step sets the grid, `random(5..5)` — `VALUE_ERROR: empty
range`. `sin`, `cos`, `tan`, and `log` are postponed: Lua can compute them, but the calls were not added to the
compiler so as not to change self-hosting for the sake of four
functions. `clamp`, `lerp`, and `is_even` are still not introduced — D95 in this part
remains in force. Documentation for all libraries is collected in `docs/libs.md`
in one file with the `math`, `cli`, `fos` parts, then `http` and non-std libraries.
Version `0.9.1` is a bump within `0.9.x`, not `1.0`.

**D121. Multiple errors per run in `1.0.0`.** Currently `fail()` writes only the
first `st[err]`; the driver prints it and exits: a file with three errors gives
one diagnostic. In the official `1.0.0` release the compiler will collect
independent errors from different statements in one pass, print each through
`report_error` (category, file, line, caret) and exit with code 1. The limit is
20 errors with deduplication by `(category, line, column)`; no flag is needed —
this is the default. Errors inside a single statement, as well as lexer errors,
remain single for now: recovery after them is ambiguous. The implementation is
only in `dev/xkraft.kraft`; the frozen `dev/kraft` v0.1 is unchanged. The
`err_multiple` test, `self-host` and `make check` are mandatory. `v0.9.1` is
already published, so the behavior changes starting with `1.0.0`.

**D122. The path `0.9.2` → `1.0.0` and the binary freeze.** `v0.9.1` is published;
we stay in `0.9.x` for now and verify changes without renaming the release.
The next step is `0.9.2`: only `async` with auto-await and an event loop are added
to the compiler (D106), without `fn`, decorators or multiline `show()`. Then
`1.0.0` is the official release of the Kraft language: static typing, a small
self-contained self-hosted binary, full async support, and multiple errors per
run (D121). From `1.0.0` on, the binary and grammar are frozen throughout `1.x`:
only libraries, modules and frameworks change. `std/http` ships in `1.1` as an
async-aware library with no binary edits (D104); LSP comes after `1.0` (D103).
The next grammar unfreeze requires a separate decision; no `2.0` number is
assigned in advance.

**D123. OOP patterns in `std/base` and multiline `show()`.** `std/base` contains
patterns, not language-level OOP: inheritance becomes composition with a parent
field plus explicit wrapper methods (delegation); polymorphism becomes a shared
protocol of identical method names plus an explicit `is` dispatcher, because a
method call on `any` is forbidden; encapsulation becomes factory functions,
`_` names and accessors; abstraction as an agreed protocol and mixins via
`dict.merge` complete the set. The limits are stated honestly: no `extends`,
subtyping, private fields, dynamic dispatch or operator overloading; `is`
checks the exact model type and `_` does not hide a field (D114). Native
multiline `show()` remains an idea with no deadline until the next grammar
unfreeze: in `1.x` multiline output is written with `\n` in strings and there is
no dedicated helper in `std/base`.

## Documentation

**D76. Where everything lives.** `docs/decisions.md` is the source of truth for
decisions. `docs/builtins.md` is the canonical list of core built-ins.
`docs/libs.md` is one file with parts for all libraries: `math`, `cli`, `fos`,
then `http` and non-std libraries. `README.md` is the guide and current behavior.
`docs/philosophy.md` covers language principles and the self-hosting criterion. `docs/rules.md`
is a historical document and is not updated. `docs/lua-for-kraft.md` contains notes on
Lua, not a specification. Every Russian-language document has an English copy
with the same name and the `.en.md` suffix; the RU original remains authoritative
in case of disagreement.
