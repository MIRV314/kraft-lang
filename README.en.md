# Kraft

[![CI](https://github.com/MIRV314/kraft-lang/actions/workflows/ci.yml/badge.svg)](https://github.com/MIRV314/kraft-lang/actions/workflows/ci.yml)
[![release v0.9.0](https://img.shields.io/badge/release-v0.9.0-blue.svg)](https://github.com/MIRV314/kraft-lang/releases)

[Русская версия](README.md) · [Releases](https://github.com/MIRV314/kraft-lang/releases)

Kraft is a small statically typed language: one numeric type (`flint`),
indentation instead of braces, and `{}` interpolation instead of string
concatenation. Errors show the category, file, line and a caret. The core grows
through libraries, not new keywords. The compiler `xkraft` is written in Kraft
and compiles itself.

Current version: **0.9.0**.

## Installation

LuaJIT is the only requirement (`luajit` must be in `PATH`).

```sh
curl -fsSL https://raw.githubusercontent.com/MIRV314/kraft-lang/main/install-auto.sh | sh
# or from a clone: sh install.sh
xkraft --version                    # xkraft 0.9.0
xkraft --update                     # update from GitHub Releases
xkraft lint [path...]               # basic style rules
```

The ready binary sits in the repository root (`./xkraft`) and in the
[releases](https://github.com/MIRV314/kraft-lang/releases).
The command to use is `xkraft`. The reference compiler `kraft` v0.1 is frozen,
lives in `dev/kraft` and is not shipped.

`xkraft --update` downloads the latest release, verifies `SHA256SUMS` and
atomically replaces the binary (on Windows, the files from `kraft-win.zip`).
The automatic version check runs once a day and only in a terminal; disable it
with `KRAFT_NO_UPDATE_CHECK=1`.

## Your first program

```kraft
str name = "Kraft"
show(hello, {name}!)
show({2 + 2})
```

```sh
xkraft hello.kraft
```

```text
hello, Kraft!
4
```

Compiling and running take one command. `xkraft -c hello.kraft` writes
`hello.lua` next to the source; `xkraft --tokens hello.kraft` prints tokens.

## Language in five minutes

```kraft
from_lib "std/fos" import read_text

flint total = 2
str word = "two"
show({word}: {total})      # two: 2

flint n = input()          # external string is converted to flint right away
show({n + 1})

func twice(flint x) -> flint:
    return x * 2

for i 1..3:                # 1, 2; the right bound is excluded
    total += i
show({twice(total)})       # 10

model Counter:
    construct(flint value):
        self(value)
    method inc(flint by) -> flint:
        self.value = self.value + by
        return self.value

Counter c = Counter(5)
show({c.inc(3)})           # 8

show({read_text("data.txt")})
```

Declarations always need a type; every function argument needs a type too.
`-> type` is for recursion and public APIs. `flint` accepts `input()`, `args()`,
`read_text()` and CSV cells without an explicit `flint(...)`: a numeric string
literal (`flint n = "42"`) is checked at compile time, a non-numeric one
(`flint n = "x"`) gives `TYPE_ERROR`; non-numeric external data gives
`TYPE_MISMATCH_ERROR` at runtime. Errors are caught with `try` / `trigger` /
`finally`.

## Dependencies

```sh
kpm init venv
kpm add ./libs/helpers     # or a URL: kpm add https://…/pkg.zip
kpm run                    # main.kraft through venv/bin/xkraft
```

`kpm add ./libs/helpers` registers a local package in the `deps` section of
`kraft.json`, copies it into `packages/helpers`, and stores the exact version
and hash in `kraft.lock`. A URL can be used instead of a path. Packages land in
`packages/<name>/`. On Windows, unpack `kraft-win.zip` and run
`install-win.cmd`.

## Not here yet

- No LSP or completion: only syntax highlighting and snippets for VS Code.
- No inheritance, polymorphism or encapsulation as language-level OOP:
  patterns live in std. There is no `class`; `model` fills that role.
  Properties remain a separate future decision.
- No `std/math`, `clamp`, `lerp` or `is_even`.
- No package registry yet: local paths and URLs only.
- No `std/http`, decorators or `async`/auto-await: planned after `1.0`.

## Where to go next

| I want… | Open |
| --- | --- |
| A syntax refresher | [RU](docs/cheatsheet.md) · [EN](docs/cheatsheet.en.md) |
| Every built-in function and method | [docs/builtins.md](docs/builtins.md) |
| The reasoning behind the language | [docs/decisions.md](docs/decisions.md) |
| Compiler rules | [docs/rules.md](docs/rules.md) |
| The project's code style | [docs/style.md](docs/style.md) |
| The philosophy | [docs/philosophy.md](docs/philosophy.md) |
| Complete small projects | [examples/README.md](examples/README.md) |
| Build and test instructions | "For developers" below |

Release plan: `0.8` — public `xkraft lint` and fractional range printing
`1.0, 1.5, 2.0`; `0.9` — `PI` in the core, the `kpm` hotfix and updated docs.
The next stable `1.0` does not include the site, registry, AUR package or
project showcase: they are postponed to a separate release. Then `std/http`
(`1.1`), decorators (`1.2`), `async` with auto-await (`1.3`) and LSP.

## For developers

Everything technical lives under `dev/`; the repo root holds the ready `xkraft`.

```text
xkraft            ready standalone binary (same file as dist/xkraft)
dist/             minimal distribution plus documentation
dev/xkraft.kraft  compiler written in Kraft
dev/kraft         frozen v0.1 reference compiler, only for self-compilation
dev/src/          runtime and reference compiler sources
dev/stdlib/       embedded modules std/fos and std/cli
dev/kpm.lua       package manager
dev/tests/        test suites
examples/         example programs
docs/             documentation
editors/vscode/   syntax highlighting and snippets
```

```sh
make check                                              # 22 + 20 + 25 + 111 + 11 + 5 tests
make dist                                               # rebuild dist/xkraft and ./xkraft
(cd dev && ./kraft xkraft.kraft xkraft.kraft > xkraft.lua)  # self-compilation
(cd dev && sh tests/stress.sh)          # outside release: stress + docs/API audit
(cd dev && sh tests/style.sh)           # outside release: basic style check
```

## License

Apache 2.0; see [LICENSE](LICENSE) and [NOTICE](NOTICE).
Repository: <https://github.com/MIRV314/kraft-lang>
