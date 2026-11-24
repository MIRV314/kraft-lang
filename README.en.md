# Kraft

[![CI](https://github.com/MIRV314/kraft-lang/actions/workflows/ci.yml/badge.svg)](https://github.com/MIRV314/kraft-lang/actions/workflows/ci.yml)
[![release v0.2.0](https://img.shields.io/badge/release-v0.2.0-blue.svg)](https://github.com/MIRV314/kraft-lang/releases/tag/v0.2.0)

[Русская версия](README.md) · [Cheatsheet](docs/cheatsheet.md) · [Built-ins](docs/builtins.md) · [Release](https://github.com/MIRV314/kraft-lang/releases/tag/v0.2.0)

Kraft is a small statically typed language: one numeric type (`flint`),
indentation instead of braces, and `{}` interpolation instead of string
concatenation. The core is deliberately tiny and frozen; everything else is
meant to grow as a library written in Kraft itself. The compiler `xkraft` is
written in Kraft and compiles itself.

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
xkraft --version                    # xkraft 0.2.0
kraft --version                     # same binary, alias name

xkraft program.kraft                # compile and run
kraft program.kraft                 # exactly the same
xkraft -c program.kraft             # write program.lua next to the source
xkraft --tokens program.kraft       # inspect tokens
xkraft program.kraft 1 2 3          # program arguments
```

From a clone, the ready binary sits in the repo root:
`./xkraft examples/features.kraft`.

## Language tour

### Values and variables

```kraft
str name = "Kraft"
flint version = 3
show(язык: {name} версия: {version})    # язык: Kraft версия: 3

flint MAX = 100                         # uppercase name = constant
```

Declarations always need an explicit type; assignments do not repeat it.

| Type | Example |
| --- | --- |
| `str` | `"text"`, `'text'` |
| `flint` | `42`, `-7`, `3.5` — one type for integers and floats |
| `bool` | `TRUE`, `FALSE` |
| `list` | `[1, 2, 3]` |
| `dict` | `{name: "Kraft", age: 25}` |
| model | `Counter(5)` |

`NONE` is the empty value. Only `FALSE` and `NONE` are falsy — `0`, `""` and
`[]` are truthy. `show` prints a template: everything outside `{}` is text,
everything inside is an expression.

```kraft
show(hello, {name}!)       # hello, Kraft!
show({version + 1})        # 4
show(\{x\})                # {x}
```

Writing `show(f(1))` instead of `show({f(1)})` is a common typo; the compiler
now tells you exactly where to put the braces.

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

The `-> type` clause is optional and checked when present; recursion needs it.
Functions are visible only after their declaration. Conditions use `AND`, `OR`,
`NOT`, and comparisons chain like in Python (`0 <= x <= 10`).

### The post-v0.1 global model

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
`del`, `remove`, `contains`, `count`, `index`, `join`, `take` and `merge`;
slicing and index assignment work on `str` and `list`. See
[builtins.md](docs/builtins.md) for the full list.

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

### Errors

A `try` block has exactly three parts: `try:`, one or more
`trigger <CATEGORY>:` branches, and a mandatory `finally:`.

```kraft
try:
    assert(FALSE, "nope")
trigger ASSERT_ERROR:
    show(caught: {error.msg})
trigger ANY_ERROR:
    show(other: {error.cat})
finally:
    show(always)
```

`error` is available in every branch and is read-only: `cat`, `msg`, `file`,
`line`, `col`, plus the `text()` method. `ANY_ERROR` catches everything else
and must come last. `finally` runs on every path, including `return`.
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

## Built-ins in a nutshell

```kraft
show({type(42)}, {type("x")}, {type(NONE)})          # flint, str, NONE
show({len("Привет")}, {len([1, 2])})                 # 6, 2
show({flint("42") + 1})                              # 43
show({sum([1, 2, 3])}, {avg([2, 4])})                # 6, 3
show({sort([3, 1, 2])})                              # [1, 2, 3]
```

There are also `map`, `filter`, `reduce`, `read_file`, `write_file`, `args`,
`exit`, `system`, `assert`, `expect`, `time_ms` and more.
`map`/`filter`/`reduce` take function names, not lambdas: `map(xs, double)`.
Built-in names are reserved and cannot be reused for variables, functions,
parameters or models (`NAME_ERROR`).

## What is implemented, what is next

- v0.1 is frozen (`v0.1.0`). `xkraft` compiles itself and produces byte-identical
  Lua on all compatibility tests.
- In `xkraft` the new model is always on: top-level declarations only, mutation
  zones, type blocks, models, index assignment, the full set of built-ins, and
  `try`/`trigger`/`finally`.
- Not implemented yet: `froz`, `panic`, stdlib prelude, modules/imports, and
  Windows setup.
- Typed collections are planned too; the syntax is already fixed:

```kraft
list[flint] nums = [1, 2, 3]
dict[str|flint] cfg = {age: 25}
froz[flint] frozen = [4, 5, 6]   # read-only list of flint
```

`froz[T]` is intended as a read-only collection built like `list[T]`. These
forms are currently rejected by the compiler and will arrive with the prelude.

Roadmap: frozen v0.1 → self-compilation → post-v0.1 core (done) → standard
library prelude in Kraft → `froz`/`panic`/modules → Windows installer.

## Repository layout

Everything technical lives under `dev/`; the repo root contains the ready
binary.

```text
xkraft            ready standalone binary (same file as dist/xkraft)
dist/             minimal distribution plus documentation
dev/kraft         frozen v0.1 reference compiler
dev/xkraft.kraft  compiler written in Kraft
dev/src/          runtime and reference compiler sources
dev/tests/        test suites
examples/         example programs
docs/             decisions, built-ins, cheatsheet
editors/vscode/   syntax highlighting and snippets
```

```sh
make check                                              # 22 + 16 + 25 + 71 tests
make dist                                               # rebuild dist/xkraft and ./xkraft
(cd dev && ./kraft xkraft.kraft xkraft.kraft > xkraft.lua)  # self-compilation
```

## License

Apache 2.0; see [LICENSE](LICENSE) and [NOTICE](NOTICE).
Repository: <https://github.com/MIRV314/kraft-lang>
