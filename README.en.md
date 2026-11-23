# Kraft

Kraft is a small statically typed language: one numeric type, indentation
instead of braces, `{}` interpolation instead of string concatenation. The
core is intentionally tiny — types, functions, collections, control flow —
and everything else is meant to grow as a standard library written in Kraft
itself.

There are two compilers:

- `kraft` — the original LuaJIT reference compiler (v0.1, frozen);
- `xkraft` — a compiler written in Kraft that compiles itself.

Both turn `.kraft` into Lua and run it with LuaJIT. No C toolchain, no build
step: one command, one run.

[Русская версия](README.md) · [Cheatsheet](docs/cheatsheet.md) ·
[v0.2.0 release](https://github.com/MIRV314/kraft-lang/releases/tag/v0.2.0)

## Quick start

```sh
git clone https://github.com/MIRV314/kraft-lang.git
cd kraft-lang
./kraft examples/hello.kraft            # frozen v0.1 compiler
./kraft -c examples/hello.kraft         # write hello.lua next to the source
./kraft examples/hello.kraft one two    # program arguments

./xkraft examples/features.kraft        # post-v0.1 language model
./xkraft examples/errors.kraft
./xkraft examples/models.kraft
./xkraft examples/script.kraft 2 3 4
```

LuaJIT is the only requirement: the `luajit` command must be in `PATH`.

## Installation

LuaJIT is the only requirement (`luajit` must be in `PATH`). The installer puts
**only `xkraft`** on your system: a single self-contained executable with the
runtime embedded. No `src/` tree and no frozen `kraft` v0.1 needed.

**Automatic** — one command; the script asks for your `sudo` password:

```sh
curl -fsSL https://raw.githubusercontent.com/MIRV314/kraft-lang/main/install-auto.sh | sh
```

It downloads tag `v0.2.0`, installs `xkraft` into `/usr/local/bin`, docs into
`/usr/local/share/doc/kraft`, and verifies the version and an example. The
command works from any directory afterwards.

**Manual** — from a clone:

```sh
sh install.sh
```

By default `xkraft` goes to `~/.local/bin` and docs to `~/.kraft`; add the bin
directory to `PATH` if needed. Both paths are overridable:

```sh
KRAFT_HOME=~/.local/share/kraft KRAFT_BIN=~/.local/bin sh install.sh
```

Check with `xkraft --version` (`xkraft 0.2.0`). The ready-to-use single file is
[`dist/xkraft`](dist/xkraft); rebuild it from sources with `make dist`.
Windows installers are not shipped yet.

## Language in five minutes

One statement per line. Blocks are indented with 4 spaces or tabs — pick one.
Comments start with `#`.

```kraft
str name = "Kraft"
flint version = 3
show(язык: {name} версия: {version})    # язык: Kraft версия: 3
```

| Type | Literals |
| --- | --- |
| `str` | `"text"`, `'text'` |
| `flint` | `42`, `-7`, `3.5` (one type for integers and floats) |
| `bool` | `TRUE`, `FALSE` |
| `list` | `[1, 2, 3]` |
| `dict` | `{name: value}` |
| model | `Название(...)` |

Declarations always require an explicit type; assignment does not repeat it.
`NONE` is the empty value. Only `FALSE` and `NONE` are falsy — `0`, `""`, `[]`
and `{}` are truthy. Uppercase names (`MAX`, `MAX_SIZE`) are hard constants.

Functions and conditions:

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

for i 1..5:
    show({i})
```

`-> type` is optional but checked when written; recursion needs it. Functions
are visible only after their declaration. Conditions use `AND`, `OR`, `NOT`;
comparisons chain like Python (`0 <= x <= 10`).

Collections have methods (`add`, `del`, `take`, `contains`, `count`, `join`,
`sort`, `reverse`, …) and higher-order functions take function names, not
lambdas: `map(xs, double)`, `filter(xs, even)`, `reduce(xs, plus, 0)`.
Built-ins include `show`, `input`, `len`, `str`, `flint`, `args`, `read_file`,
`assert`, `expect`, `time_ms`. See [builtins.md](docs/builtins.md).

### The post-v0.1 model (`xkraft`)

The top level only declares. Globals can be reassigned only directly inside a
`func`, `for` or `while`; `if`/`elif`/`else` do not open a mutation zone.
Locals, parameters and `for` counters cannot shadow a global name
(`REDECLARE_ERROR`). No directives, modes or opt-outs exist.

```kraft
flint total = 0

func add_points(flint n):
    total += n          # writing a global needs no `ext`

for i 10:
    total += i          # loops are mutation zones too

add_points(10)
show({total})           # 55
```

### Models

Fields are created in `construct`: `self(a, b)` creates fields named after the
parameters. Fields declared in the model body are read-only.

```kraft
model Counter:
    construct(flint value):
        self(value)
    method inc(flint by) -> flint:
        self.value = self.value + by
        return self.value

Counter c = Counter(5)
show({c.inc(3)})        # 8
show({c is Counter})    # TRUE
```

### Errors

Compile-time errors print the category, file and line, the source line, and a
caret under the problem:

```
TYPE_ERROR: name.kraft:2
    2 | flint x = "text"
                       ^ expected declaration of 'x': type flint, found str
```

Runtime errors are handled with `try` / `trigger` / `finally`:

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

`ANY_ERROR` must be last; `finally` is mandatory and runs on every path,
including `return`. `error` is a read-only object with fields `cat`, `msg`,
`file`, `line`, `col` and method `text()`.

## Status

- v0.1 is frozen (`v0.1.0`) and remains the reference compiler; `kraft`
  still compiles exactly v0.1.
- `xkraft` is written against frozen v0.1, compiles itself, and produces
  byte-identical Lua on all compatibility tests.
- In `xkraft`, the new model is always on: top-level declarations only,
  mutation zones, models, full set of built-ins, and error handling.
  `xkraft.kraft` itself stays in v0.1 syntax.
- `froz`, `panic`, stdlib prelude and modules are reserved but not
  implemented yet. Windows setup is planned for a later release.

Run `make check` to run the full test suite (reference compiler, xkraft
compatibility, new model, CLI).

## License

Apache 2.0; see [LICENSE](LICENSE) and [NOTICE](NOTICE).
