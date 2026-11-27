# Kraft cheatsheet

Reference for `0.8.0`. Full docs: [English README](../README.en.md),
[builtins](builtins.md), [decisions](decisions.md),
[philosophy](philosophy.md). Russian version:
[README](../README.md), [cheatsheet](cheatsheet.md).

## Running

```sh
xkraft file.kraft [args...]         # current compiler, new model
xkraft -c file.kraft                # executable file.lua next to the source
xkraft --tokens file.kraft
xkraft --version                    # xkraft 0.8.0
xkraft --update                     # check and update from GitHub Releases
xkraft lint [path...]               # basic style rules (docs/style.md)
kpm init venv                       # kraft.json, kraft.lock, venv/, packages/
kpm add ./local-package             # register in deps, copy into packages/
kpm list
kpm run                             # run main.kraft through the venv
kpm del local-package
```

From a clone use `./xkraft` in the repo root. The frozen v0.1 reference
compiler lives in `dev/kraft` for self-hosting checks only and is never
installed. The canonical command is `xkraft`; the installer may alias `kraft`
to it.

Requires `luajit` in `PATH`. Install: `sh install.sh` (into `~/.kraft` and
`~/.local/bin`) or `install-auto.sh` (one command, `/usr/local`, asks for
`sudo`).

On Windows: unpack `kraft-win.zip`, run `install-win.cmd`; LuaJIT must already
be in `PATH`. Both `xkraft.cmd` and `kraft.cmd` start the same compiler.

## Syntax and values

```kraft
# comment; --- ... --- is a multi-line comment
str name = "Kraft"          # declarations: type is mandatory
flint n = 3.5               # one numeric type for ints and floats
bool ok = TRUE
list xs = [1, 2, 3]
dict cfg = {name: "Kraft"}
show(hello: {name}, n={n})  # interpolation, not concatenation
```

Indentation defines blocks: 4 spaces or tabs, never mixed. One statement per
line, no semicolons. `NONE` and `FALSE` are false, `TRUE` is true. Uppercase
names (`MAX`, `MAX_SIZE`) are hard constants: writing to them gives
`CONST_ERROR`.

`flint` takes external strings without an explicit `flint(...)`:
`flint age = input()`, `flint port = args()[1]`. A numeric string literal is
checked at compile time: `flint n = "42"` is allowed, `flint n = "x"` gives
`TYPE_ERROR`. Non-numeric external data gives
`TYPE_MISMATCH_ERROR: expected flint, found str: <value>` at runtime. Explicit
`flint(x)` and `str(x)` remain; there is no `list()` or `dict()` cast.

`iinput()` is an idea only (D112): no arguments, the prompt comes from the
variable name, so `flint age = iinput()` would show `age: `. Not added to the
core or std.

Types: `str`, `flint`, `bool`, `list`, `froz`, `dict`, `model`. A block of
declarations of one type is allowed:

```kraft
str:
    a = "one"
    b = "{a} two"
```

## Operators

- Arithmetic: `+ - * / // % **` (Python semantics: `/` is true division,
  `//` floors, `%` follows the divisor), unary `-`.
- Comparison: `== != < <= > >=`; chained like Python (`0 <= x <= 10`).
- Logic: `AND`, `OR`, `NOT`. Type check: `n is flint`.
- Range: `1..5` yields `1, 2, 3, 4` (right bound excluded); `1..10..2`
  steps by 2, `1..10..0.5` steps by 0.5. Range bounds are always integers.
- Membership: `if age in 0..17`, `if x in xs`, `if k in d`.
- Strings are joined with interpolation or `xs.join(sep)`, never with `+`.
- Compound assignment: `+= -= *= /= //= %= **=` (numbers only).

## Control flow

```kraft
if n > 0:
    show(positive)
elif n == 0:
    show(zero)
else:
    show(negative)

for i 5:                    # 0, 1, 2, 3, 4
    show({i})
for i 5..9:                 # 5..8, right bound excluded
for i 10..0..-2:            # step sets direction
for x in xs:                # iterate elements
while n > 0:
    n -= 1
    if n == 3:
        break
```

## Functions and globals

```kraft
func add(flint a, flint b) -> flint:
    return a + b
```

- `func` only at top level; no nested functions. Functions are visible only
  after their declaration.
- Every function argument needs a type. `-> type` is optional but checked;
  recursion and public APIs need it.
- A function sees file-level globals. In `xkraft`, the top level only
  declares: globals may be reassigned only directly inside `func`, `for` or
  `while`, never on a plain top-level line or inside `if`/`elif`/`else`
  (`TOPLEVEL_ERROR`). No `ext` keyword.
- Locals, parameters and `for` counters may not shadow a global
  (`REDECLARE_ERROR`).

## Collections

```kraft
list xs = [3, 1, 2]
xs.add(4)
xs.del(0)
show({xs.contains(2)})      # TRUE
show({map(xs, double)})     # function by name, no lambdas
show({filter(xs, even)})
show({reduce(xs, plus, 0)})
show({xs[0]})               # indexing and slices: s[2..7], s[..5], xs[1..5..2]
xs[0] = 10                  # post-v0.1: index assignment
```

Type parameters are optional and only for specific tasks:

```kraft
list nums = [1, 2, 3]
list[flint] ints = [1, 2, 3]
dict[str|flint] cfg = {"age": 25}   # dict[str, flint] is the same
froz[flint] frozen = [4, 5]         # read-only
```

Inside `[]`: only `str`, `flint`, `bool`; no nesting and no `NONE`. In `dict`
the left type is the key (`str` or `flint`), the right type is the value. A bare
name equals the quoted string. `froz` supports reads, slices and `for in`;
writes and mutating methods are errors.

Prelude is available without `import`: `prelude_cat`, `path_join`, `now_ms`,
`parse_args`, `parse_csv`, `parse_json`. Add `--no-prelude` to disable it.

Built-ins: `len`, `type`, `str`, `flint`, `up`, `low`, `title`, `abs`, `round`,
`floor`, `ceil`, `sqrt`, `factorial`, `fib`, `min`, `max`, `sum`, `avg`, `keys`,
`values`, `upk`, `sort`, `reverse`, `clear`, `map`, `filter`, `reduce`,
`read_file`, `write_file`, `file_exists`, `args`, `exit`, `time_ms`, `is_tty`,
`system`, `assert`, `expect`, `show`, `show_err`, `input`. Output and input are
only `show` / `show_err` / `input`.

`keys(d)` and `values(d)` return new lists of keys and values. `upk(coll)` gives
the contents without outer brackets: `[1, "два"]` → `1, "два"`; D113 plans to
drop the commas (`1 "два"`). A `?` in the docs marks an optional argument; it
is never written in code: `s.part(",")`, `s.remove("x")`.

All names are reserved: a user declaration cannot reuse a built-in or a method
name (`add`, `take`, `contains`, `count`, `text`, …).

## Models (xkraft)

```kraft
model Counter:
    construct(flint value):
        self(value)             # creates the `value` field
    method inc(flint by) -> flint:
        self.value = self.value + by
        return self.value

Counter c = Counter(5)
show({c.inc(3)})                # 8
show({c is Counter})            # TRUE
```

Fields are created in `construct`: `self(a, b)` creates fields named after the
parameters; `self.hp = 100` changes a field that already exists. There is no
`class`; `model` fills that role. Inheritance and polymorphism live as std
patterns, not as language-level OOP.

## Errors

Compile-time errors show the category, file, line, source and a caret:

```
CONST_ERROR: file.kraft:3
    3 | MAX = 5
              ^ expected mutable target, found constant 'MAX'
```

Runtime errors can be caught in `xkraft`:

```kraft
try:
    assert(FALSE, "bad")
trigger ASSERT_ERROR, VALUE_ERROR:  # one handler for both
    show(caught: {error.cat})
trigger ANY_ERROR:              # must be last
    show(other: {error.cat})
finally:                        # mandatory
    show(always)
```

`error` is read-only: fields `cat`, `msg`, `file`, `line`, `col`, method
`text()`. An error raised inside a `trigger` branch is not caught by the same
block; `break`/`continue` cannot cross a `try` boundary.

`panic("CATEGORY"[, "message"])` raises a known category; without a message
the category is used as `error.msg`. It is caught by `trigger CATEGORY` or
`trigger ANY_ERROR` exactly like a runtime error.

Categories: `SYNTAX_ERROR`, `NAME_ERROR`, `REDECLARE_ERROR`, `CONST_ERROR`,
`TOPLEVEL_ERROR`, `TYPE_ERROR`, `SCOPE_ERROR`, `ARGCOUNT_ERROR`,
`VALUE_ERROR`, `CONCATENATE_NOT_SUPPORT`, `FILE_ERROR`,
`TYPE_MISMATCH_ERROR`, `PANIC_ERROR`, `RUNTIME_ERROR`, `GENERATE_ERROR`,
`ASSERT_ERROR`, `EXPECT_ERROR`.

## Modules, stdlib and packages (0.5)

`import_file` / `from_file` work with local files, `import_lib` / `from_lib`
with bundled libraries, and `namespace` groups declarations. Every top-level
name is importable. A `_` or `__` prefix is only a hint for the reader; it does
not hide the name.

```kraft
import_lib "std/fos"
from_lib "std/fos" import read_json, write_csv
import_lib "std/cli"
```

`std/fos` is File Operating System: `exists`, `copy`, `remove`, `read_text`,
`write_text`, `read_json`, `write_json`, `read_csv`, `write_csv`, plus
`csv_field`, `csv_line`, `csv_parse`. `std/cli` has `run` and `kill`.
`system(command)` is the built-in `/bin/sh -c` call; `cli.run(command)` is a
wrapper in `std/cli`; both return the exit code.

There is no `std/fs`, `std/json`, `std/math`, `clamp`, `lerp` or `is_even`;
`fib` and `factorial` are builtins.

```sh
kpm init venv        # kraft.json, kraft.lock, venv/, packages/
kpm add ./pkg        # local path or URL
kpm list
kpm run
kpm del pkg
```
