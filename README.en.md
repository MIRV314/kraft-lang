# Kraft

> **This repository is frozen.** Development continues in [AXI](https://github.com/MIRV314/axi-lang).

[![CI](https://github.com/MIRV314/kraft-lang/actions/workflows/ci.yml/badge.svg)](https://github.com/MIRV314/kraft-lang/actions/workflows/ci.yml)
[![release v0.9.4](https://img.shields.io/badge/release-v0.9.4-blue.svg)](https://github.com/MIRV314/kraft-lang/releases)

[Русская версия](README.md) · [Releases](https://github.com/MIRV314/kraft-lang/releases)

Kraft is a small statically typed language: one numeric type (`flint`),
indentation instead of braces, and `{}` interpolation instead of string
concatenation. Errors show the category, file, line and a caret. The core grows
through libraries, not new keywords. The compiler `xkraft` is written in Kraft
and compiles itself. It reports up to 10 independent errors per run, one per line.

Current version: **0.9.4**; the latest published release is **v0.9.4**.

## Installation

LuaJIT is the only requirement (`luajit` must be in `PATH`).

```sh
curl -fsSL https://raw.githubusercontent.com/MIRV314/kraft-lang/main/install-auto.sh | sh
# or from a clone: sh install.sh
kraft --version                     # xkraft 0.9.4; kraft is the alias
kraft --update                      # update binary and kpm from GitHub Releases
xkraft lint [path...]               # basic style rules
kpm --version                       # kpm 1.0.0
```

The ready binary sits in the repository root (`./xkraft`) and in the
[releases](https://github.com/MIRV314/kraft-lang/releases).
The main command is `kraft`; the same binary is available as `xkraft`. The
frozen `kraft` v0.1 lives in `dev/kraft` and is not shipped.

`kraft --update` (`xkraft --update`) downloads the latest release, verifies both
hashes against `SHA256SUMS` and only then replaces the binary and `kpm`. The
replacement copies into a temporary file next to the target, so it works across
filesystems. On Windows, the files from `kraft-win.zip` are updated. The
automatic version check runs once a day and only in a terminal; disable it with
`KRAFT_NO_UPDATE_CHECK=1`. `kpm update` is gone: `kpm` no longer updates itself.

Both POSIX installers place `xkraft`, `kpm` and the `kraft` alias. The AUR package
does not create the `kraft` alias. `kpm --version` reports `1.0.0`.

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

In slices `..` separates bounds and `...` sets the step: `xs[..2]` — up to index
2 (excluded), `xs[2..]` — to the end, `xs[...2]` — the whole list with step 2,
`xs[2...3]` — from 2 to the end with step 3, `xs[...]` — a full copy. An empty
branch or loop body is written with `pass`.

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
  patterns over `model`/`dict`/`self` are already in `std/base` from `0.9.2`.
  There is no `class`; `model` fills that role. Properties remain a separate
  future decision (D123).
- No `sin`, `cos`, `tan` or `log` in `std/math` yet: only `pow` and `random`.
- `clamp`, `lerp` and `is_even` are not introduced.
- No package registry yet: local paths and URLs only.
- `async`/auto-await and the event loop are available from `0.9.2`; `std/http`
  follows in `1.1`, already async-aware (D104, D106).
- No decorators, `fn` lambdas or multiline `show()`: ideas with no deadline, not
  added in `1.x` (D105, D115, D123).

## Where to go next

| I want… | Open |
| --- | --- |
| A syntax refresher | [docs/cheatsheet.en.md](docs/cheatsheet.en.md) |
| Every built-in function and method | [docs/builtins.en.md](docs/builtins.en.md) |
| A guide to the libraries | [docs/libs.en.md](docs/libs.en.md) |
| The reasoning behind the language | [docs/decisions.en.md](docs/decisions.en.md) |
| Compiler rules | [docs/rules.en.md](docs/rules.en.md) |
| The project's code style | [docs/style.en.md](docs/style.en.md) |
| The philosophy | [docs/philosophy.en.md](docs/philosophy.en.md) |
| Complete small projects | [examples/README.en.md](examples/README.en.md) |
| Build and test instructions | "For developers" below |

Release plan: `0.8` — public `xkraft lint` and fractional range printing
`1.0, 1.5, 2.0`; `0.9.1` — `PI`, the `kpm` hotfix, `std/math` and updated docs.
We stay in `0.9.x` for now and verify changes: `0.9.2` added `async` with
auto-await (D106), `0.9.3` added multiple errors per run (D121), and `0.9.4`
is a docs-only cleanup. All three are separate published releases. Then
`1.0.0` is the official release:
static typing, a small self-hosted binary, full async support and the same
multiple-error diagnostics. From `1.0` the binary and grammar are frozen:
`std/http` ships in `1.1` as an
async-aware library, followed by other libraries and modules; LSP comes after
`1.0`. The site, registry, AUR package and showcase are postponed to a separate
release. Decorators, `fn` and multiline `show()` are ideas with no deadline
until the next grammar unfreeze (D122).

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

The frozen `kraft` v0.1 does not know the new syntax (`pass`, the new slice
forms): it is only for self-compilation. New code requires `xkraft` or the
`kraft` alias from the distribution.

```sh
make check                                              # 22 + 20 + 25 + 115 + 13 + 6 + 9 tests
make dist                                               # rebuild dist/xkraft and ./xkraft
(cd dev && ./kraft xkraft.kraft xkraft.kraft > xkraft.lua)  # self-compilation
(cd dev && sh tests/stress.sh)          # outside release: stress + docs/API audit
(cd dev && sh tests/style.sh)           # outside release: basic style check
```

## License

Apache 2.0; see [LICENSE](LICENSE) and [NOTICE](NOTICE).
Repository: <https://github.com/MIRV314/kraft-lang>
