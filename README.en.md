# Kraft

[![CI](https://github.com/MIRV314/kraft-lang/actions/workflows/ci.yml/badge.svg)](https://github.com/MIRV314/kraft-lang/actions/workflows/ci.yml)
[![release v0.5.0](https://img.shields.io/badge/release-v0.5.0-blue.svg)](https://github.com/MIRV314/kraft-lang/releases/tag/v0.5.0)

[Русская версия](README.md) · [Cheatsheet](docs/cheatsheet.md) · [Built-ins](docs/builtins.md) · [Philosophy](docs/philosophy.md) · [Release](https://github.com/MIRV314/kraft-lang/releases/tag/v0.5.0)

Kraft is a small statically typed language: one numeric type (`flint`),
indentation instead of braces, and `{}` interpolation instead of string
concatenation. Errors speak plainly: category, file, line and a caret. The core
stays tiny and grows through libraries, not new keywords. The compiler `xkraft`
is written in Kraft and compiles itself — proof that the language can carry
real programs.

- **One command.** `.kraft` → Lua → LuaJIT. No C toolchain, no build step.
- **One binary.** After installation `xkraft` and `kraft` are two names for the
  same x binary; the frozen v0.1 reference compiler is never installed.
- **One language for everything.** The core, the examples and the compiler are
  all written in Kraft.

## Quick start

LuaJIT is the only requirement (`luajit` must be in `PATH`).

```sh
curl -fsSL https://raw.githubusercontent.com/MIRV314/kraft-lang/main/install-auto.sh | sh
```

Or install from a clone: `sh install.sh` (defaults to `~/.local/bin`).

```sh
xkraft --version                    # xkraft 0.5.0
kraft --version                     # same binary, alias name

xkraft program.kraft                # compile and run
kraft program.kraft                 # exactly the same
xkraft -c program.kraft             # write program.lua next to the source
xkraft --tokens program.kraft       # inspect tokens
xkraft program.kraft 1 2 3          # program arguments

kpm init venv                       # kraft.json, kraft.lock, venv/, packages/
kpm add ./local-package             # or a URL: kpm add https://…/pkg.zip
kpm list                            # installed packages
kpm run                             # run main.kraft through venv/bin/xkraft
kpm del local-package               # remove a dependency
```

From a clone, the ready binary sits in the repo root:
`./xkraft examples/features.kraft`.
Two small complete projects: `examples/mini-calc.kraft` (arguments and models)
and `examples/mini-report.kraft` (CSV via `std/fos`).

## Language tour

### Values and variables

```kraft
str name = "Kraft"
flint version = 3
show(язык: {name} версия: {version})    # язык: Kraft версия: 3

flint MAX = 100                         # uppercase name = constant
```

Declarations always need an explicit type; assignments do not repeat it.

`flint` accepts strings from the outside without an explicit cast — `input()`,
`args()[i]`, `read_text()`, CSV cells. A numeric string is converted at runtime;
non-numeric input gives `TYPE_MISMATCH_ERROR: expected flint, found str: <value>`.
A literal `flint n = "x"` is a compile-time error: a letter cannot be a number.
Explicit `flint(x)` and `str(x)` remain.

| Type | Example |
| --- | --- |
| `str` | `"text"`, `'text'` |
| `flint` | `42`, `-7`, `3.5` — one type for integers and floats |
| `bool` | `TRUE`, `FALSE` |
| `list` | `[1, 2, 3]` |
| `dict` | `{name: "Kraft", age: 25}` |
| `froz` | `[4, 5, 6]` — read-only |
| `model` | `Counter(5)` |

`NONE` may be false, `FALSE` is false, `TRUE` is true.

```kraft
show(hello, {name}!)       # hello, Kraft!
show({version + 1})        # 4
show(\{x\})                # {x}
```

Writing `show(f(1))` instead of `show({f(1)})` is a common typo; the compiler
tells you exactly where to put the braces.

### Functions, conditions, loops

```kraft
func summ(flint a, flint b) -> flint:
    return a + b

flint n = summ(2, 3)
if n > 4:
    show(big: {n})
elif n == 4:
    show(four)
else:
    show(small: {n})

for i 1..5:                 # 1, 2, 3, 4
    show({i})

flint i = 0
while i < 3:
    i += 1
```

`-> type` is a return-type annotation — an optional specification of the result
type. When omitted, the compiler infers it from `return`; recursion requires the
annotation.

```kraft
func inc(flint n):              # no annotation — type is inferred
    return n + 1

func dec(flint n) -> flint:     # annotation given explicitly
    return n - 1
```

Functions are visible only after their declaration. Conditions use `AND`, `OR`,
`NOT`, and comparisons chain like in Python (`0 <= x <= 10`).

`..` builds a range with the right bound excluded; there is no separate `range`
declaration — ranges are written inline. Bounds are always integers, the step
may be fractional:

```kraft
for i 1..5:                 # 1, 2, 3, 4
    show({i})
for x 1..10..0.5:           # 1, 1.5, 2, …, 9.5
    show({x})
show({xs[1..3]})            # slice: elements 1 and 2
if age in 0..17:            # half-open interval membership
    show(child)
```

`in` iterates `list`/`froz` and `dict` keys (`for x in xs`, `for k, v in d`)
or checks membership. The numeric range loop is written without `in`.

### Globals in xkraft

In `xkraft` the top level only declares. A global can be reassigned only
directly inside a `func`, `for` or `while`; `if`/`elif`/`else` do not open a
mutation zone.

```kraft
flint total = 0

func add_points(flint n):
    total += n          # no `ext` keyword needed

for i 10:
    total += i          # loops are mutation zones too

add_points(10)
show({total})           # 55
```

Locals, parameters and `for` counters cannot shadow a global name
(`REDECLARE_ERROR`). Uppercase names are hard constants: writing to one is a
`CONST_ERROR`. There are no directives, modes or switches for this behaviour.

### Collections

```kraft
list xs = [1, 2, 3]
xs.add(4)
xs.del(0)
show({xs.join("-")})        # 2-3-4
show({xs.contains(3)})      # TRUE

dict user = {name: "Kraft", age: 25}
show({user[name]})          # Kraft
user.add("height", 180)
for k, v in user:
    show({k} = {v})
```

Lists and dictionaries are passed by reference. Common methods include `add`,
`del`, `remove`, `contains`, `count`, `index`, `join`, `take`, `merge`,
slicing and index assignment. See [builtins.md](docs/builtins.md) for the full
list. A dict key is `str` or `flint`; a bare name equals the quoted string.

### Models

Fields are created in `construct` with `self(...)`. Fields declared in the
model body are read-only; there is no inheritance.

```kraft
model Counter:
    construct(flint value):
        self(value)
    method inc(flint by) -> flint:
        self.value = self.value + by
        return self.value

Counter c = Counter(5)
show({c.inc(3)})        # 8
```

No inheritance, polymorphism, encapsulation, properties, `class` or operator
overloading before 1.0.

### Errors

A `try` block has exactly three parts: `try:`, one or more
`trigger <CATEGORY>:` branches, and a mandatory `finally:`.

```kraft
try:
    assert(FALSE, "nope")
trigger ASSERT_ERROR, VALUE_ERROR:  # one branch for both
    show(caught: {error.cat})
trigger ANY_ERROR:
    show(other: {error.cat})
finally:
    show(always)
```

`error` is available in every branch and is read-only: `cat`, `msg`, `file`,
`line`, `col`, plus the `text()` method. `ANY_ERROR` catches everything else
and must come last and cannot be grouped. A comma-separated list of categories
shares one branch. `finally` runs on every path, including `return`.

`panic("CATEGORY"[, "message"])` raises a known category; without a message
the category becomes `error.msg`. It is caught by `trigger CATEGORY` or
`trigger ANY_ERROR` just like a runtime error.

Compile-time errors print the category, file, line, source line and a caret:

```text
TYPE_ERROR: name.kraft:2
    2 | flint x = "text"
                       ^ expected declaration of 'x': type flint, found str
```

### Strings in more detail

Strings use double quotes or single quotes. Escapes include `\\`, `\"`, `\'`,
`\n`, `\t`, `\r`, `\e`, `\{` and `\}`. Inside `show(...)`, parentheses are call
syntax, so literal parentheses must be escaped: `show(a \(b\))` → `a (b)`.
String concatenation with `+` is not allowed — use interpolation or
`list.join(separator)`.

## Modules and namespaces

Every top-level declaration of a module is importable — there is no `export`,
and a `_` prefix does not create privacy:

```kraft
# math.kraft
flint LIMIT = 10

func twice(flint x) -> flint:
    return x * 2
```

```kraft
import_file "./math.kraft"                  # all names: LIMIT, twice
from_file "./math.kraft" import twice       # selected names only

show({twice(3)})
```

A `namespace` grouping accepts declarations and functions; members are reached
with a dot from outside, while short names work inside:

```kraft
namespace util:
    flint base = 3
    func inc(flint x) -> flint:
        return x + base

show({util.inc(4)})     # 7
```

Imported namespaces work the same way: `import_file "./grid.kraft"` gives
`grid.size` and `grid.area(2, 3)`.

## Standard library

Two modules are embedded in the distribution — no separate files and no venv
needed:

```kraft
import_lib "std/fos"                        # fos.exists/copy/remove/read_text/...
from_lib "std/fos" import read_json, write_json, read_csv, write_csv
import_lib "std/cli"                        # cli.run/kill

show({fos.exists("data.txt")})
```

`std/fos` means File Operating System: `exists`, `copy`, `remove`, `read_text`,
`write_text`, `read_json`, `write_json`, `read_csv`, `write_csv`. `csv_field`,
`csv_line` and `csv_parse` are ordinary top-level names available through
`from_lib`. `std/cli` has only `run(command)` and `kill(message)`.

`std/fs`, `std/json`, `std/file`, `std/math`, `clamp`, `lerp` and `is_even` are
not shipped. `json_parse` and `json_stringify` stay internal builtins.

The prelude needs no `import`: `path_join`, `now_ms`, `parse_args`,
`parse_csv`, `parse_json`, `prelude_cat`. Use `--no-prelude` to disable it.

## Packages and venv

`kpm init venv` creates `kraft.json`, `kraft.lock`, `venv/` and `packages/`,
plus a copy of `xkraft` in `venv/bin/`. On Windows it also writes
`venv/bin/xkraft.cmd` next to `xkraft-win.lua`. Dependencies are local paths
or URLs and land in `packages/<name>/`:

```sh
kpm init venv my-game
kpm add ./libs/helpers
kpm add https://example.org/tiles.zip
kpm run                 # run main.kraft through venv/bin/xkraft
```

```json
{
  "name": "my-game",
  "version": "0.1.0",
  "main": "main.kraft",
  "deps": {"helpers": "./libs/helpers"}
}
```

`kraft.lock` pins the source, path and hash of each installed package. The
registry and moderation arrive in `1.1`; `1.0` supports paths and URLs only.

## Built-ins in a nutshell

```kraft
show({type(42)}, {type("x")}, {type(NONE)})          # flint, str, NONE
show({len("Привет")}, {len([1, 2])})                 # 6, 2
show({flint("42") + 1})                              # 43
show({sum([1, 2, 3])}, {avg([2, 4])})                # 6, 3
show({factorial(5)}, {fib(10)})                      # 120, 55
show({sort([3, 1, 2])})                              # [1, 2, 3]
```

There are also `map`, `filter`, `reduce`, `read_file`, `write_file`, `args`,
`exit`, `system`, `assert`, `expect`, `time_ms` and more. Output and input are
`show`, `show_err` and `input` — no `read()`, `ask()`, `echo` or `$` syntax.
`map`/`filter`/`reduce` take function names, not lambdas: `map(xs, double)`.
Built-in names are reserved and cannot be reused for variables, functions,
parameters or models (`NAME_ERROR`).

## What is implemented, what is next

- v0.1 is frozen (`v0.1.0`). `xkraft` compiles itself and produces byte-identical
  Lua on all compatibility tests.
- In `xkraft` the 1.0 model is always on: top-level declarations only, mutation
  zones, type blocks, models, index assignment, the full set of built-ins, and
  `try`/`trigger`/`finally`.
- Implemented: `froz`, `panic`, prelude, `..` ranges, `in`, grouped
  `trigger CAT1, CAT2:`, modules and imports (`import_file`, `from_file`,
  `import_lib`, `from_lib`), namespaces, `std/fos`, `std/cli` and `kpm` with
  venv. `export` is gone; all top-level names are importable and `_` does not
  mean private.
- `fib` and `factorial` are builtins. There is no `std/math`, `clamp`, `lerp`
  or `is_even`.
- Models have no inheritance, polymorphism, encapsulation, properties,
  `class` or operator overloading.
- The package registry and moderation are planned for `1.1`.

Type parameters are optional and only for specific tasks:

```kraft
list nums = [1, 2, 3]             # plain list, as before
list[flint] ints = [1, 2, 3]      # flint elements only
dict[str|flint] cfg = {age: 25}   # str key, flint value
froz[flint] frozen = [4, 5, 6]    # read-only
```

`dict[str, flint]` is equivalent to `dict[str|flint]`: the left type is the
key (`str` or `flint`), the right type is the value. Inside `[]` only `str`,
`flint` and `bool` are allowed; nesting and `NONE` are rejected. `froz[T]`
supports reads, indexes, slices and `for in`, but no writes or mutating
methods.

On Windows, unpack `kraft-win.zip` and run `install-win.cmd` with LuaJIT
available in `PATH`. `xkraft` and `kraft` run the same program.

Roadmap: frozen v0.1 → self-compilation → post-v0.1 core → prelude, `froz`,
`panic`, Windows (done) → modules/imports, stdlib and `kpm` (done) → registry
in `1.1`.

## Repository layout

Everything technical lives under `dev/`; the repo root contains the ready
binary.

```text
xkraft            ready standalone binary (same file as dist/xkraft)
kpm               standalone package manager
dist/             minimal distribution plus documentation
dev/kraft         frozen v0.1 reference compiler
dev/xkraft.kraft  compiler written in Kraft
dev/src/          runtime and reference compiler sources
dev/stdlib/       embedded modules std/fos, std/cli
dev/kpm.lua       package manager (LuaJIT)
dev/tests/        test suites
examples/         example programs
docs/             decisions, built-ins, cheatsheet, philosophy
editors/vscode/   syntax highlighting and snippets
```

```sh
make check                                              # 22 + 20 + 25 + 111 + 11 tests
make dist                                               # rebuild dist/xkraft and ./xkraft
(cd dev && ./kraft xkraft.kraft xkraft.kraft > xkraft.lua)  # self-compilation
(cd dev && sh tests/stress.sh)          # outside release: stress + docs/API audit
(cd dev && sh tests/style.sh)           # outside release: basic style check
```

## License

Apache 2.0; see [LICENSE](LICENSE) and [NOTICE](NOTICE).
Repository: <https://github.com/MIRV314/kraft-lang>
