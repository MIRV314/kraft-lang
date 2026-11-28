# Changelog

> Russian original: [CHANGELOG.md](CHANGELOG.md). The Russian version is authoritative.

## 1.0.0 (planned)

- The official release of the Kraft language: static typing, a small
  self-contained self-hosted binary with full async support from `0.9.2`,
  multiple-error diagnostics from `0.9.3`, and a grammar stable throughout
  `1.x` (D122).
- Built-in `std/base` with OOP patterns over `model`/`dict`/`self`: composition
  and delegation instead of inheritance, a protocol plus an explicit `is`
  dispatcher instead of polymorphism, factories and `_` names with accessors
  instead of encapsulation (D110, D123).
- From `1.0.0` the binary and grammar are frozen: only libraries and modules
  change afterwards. `std/http` ships in `1.1` as an async-aware library, LSP
  comes after `1.0`.

## v0.9.3 (published 28 November 2026)

[Release](https://github.com/MIRV314/kraft-lang/releases/tag/v0.9.3)

- Multiple errors in one run (D121): the compiler collects independent errors
  from different statements, prints each with category, file, line and caret,
  and exits with code 1. The limit is 10, at most one error per line; enabled
  by default with no flag.
- Cascading `NAME_ERROR`s after failed declarations are suppressed, and after
  an error the parser skips the rest of the statement or block instead of
  filling the output with noise. Errors inside one line and lexer errors stay
  single.
- New regressions: three independent errors, the limit of 10, and one error
  inside a single line. Grammar, runtime and frozen `dev/kraft` v0.1 are
  unchanged; self-hosting and the double build remain byte-stable.

## v0.9.2 (published 28 November 2026, separate release)

[Release](https://github.com/MIRV314/kraft-lang/releases/tag/v0.9.2)

- `async` as a keyword in place of `func`, a future as the result type, and
  automatic await at the first use of the value (D106). In `0.9.2` timers and
  test futures are suspended; `std/http` arrives in `1.1` and is immediately
  async-aware (D104).
- An event loop and coroutine scheduler in `dev/src/krt.lua`, plus updates to
  the VS Code grammar and lint. Frozen `dev/kraft` v0.1 is unchanged;
  self-hosting and byte-stable double builds are mandatory.
- Built-in `timer(ms, value)` as a suspendable test operation: monotonic clock,
  real waiting time and parallel future starts. A future's error is raised at
  the await point, not at the call site.
- An import regression matrix: all std modules, `import_lib`/`from_lib`,
  `import_file`/`from_file`, plus errors for missing modules, missing exports,
  shadowing and nested imports.
- `fn` lambdas, decorators and native multiline `show()` are not added: ideas
  with no deadline until the next grammar unfreeze (D105, D115, D123).

## v0.9.1

- The ready binary `xkraft` (alias `kraft`) is built and ready for the
  `0.9.1` release; the tag and publication are created separately.
- Built-in `std/math`: `pow(a, b)` and `random(x)`. `random(start..stop..step)`
  works with integer and fractional steps under D87/D88, `random(list)` returns
  a random element, `random(5..5)` gives `VALUE_ERROR: empty range`.
  `sin`, `cos`, `tan`, `log`, `clamp`, `lerp`, and `is_even` are not added (D120).
- D120 cancels part of D94/D95/D119 regarding `std/math`; the older
  decisions remain as history. D87/D88 are fulfilled in the `random` part.
- New slice forms: `xs[a...step]`, `xs[...step]`, `xs[a...]`, and `xs[...]`.
  `..` separates bounds, `...` sets the step; there are no `...` forms in loops (D117).
- The empty statement `pass` for empty branches and loop bodies (D118).
  Implemented in `dev/xkraft.kraft`; frozen `kraft` v0.1 unchanged, self-hosting preserved.
- The core/std audit is complete (D119): nothing is moved out of the core. `PI`,
  `fib`, `factorial` are fixed; `clamp`, `lerp`, and `is_even` are not introduced.
  `class` is not added — its role is filled by `model`.
- The only update command is `kraft --update` (`xkraft --update`): it updates
  both the binary and `kpm`. `kpm update` / `kpm --update` are removed, the Lua
  updater duplicate is deleted. Both hashes are checked against `SHA256SUMS` before
  any replacement; replacement is cross-device-safe. `kpm --version` shows `1.0.0` (D116).
- Both POSIX installers place `kpm` alongside `xkraft` and the alias `kraft`; frozen
  `kraft` v0.1 is still not installed. There is no alias in the AUR package.
- Documentation: `docs/libs.md` with per-library sections, complete RU/EN pairs
  for every Russian-language md file, plus a note that the new syntax is known
  to `xkraft`, not to frozen `kraft` v0.1.
- The website, package registry, AUR package, and example showcase are postponed
  beyond `1.0` to a separate release.
- D111 (`method.type`) and D112 (`iinput`) remain ideas with no deadline.

## v0.9.0

- Built-in constant `PI`: `show({PI})` prints `3.1415926535898`.
  It is in the core; there is no separate `std/math`; `clamp`, `lerp`, and `is_even` are not introduced.
- `kpm`: XOR without `~` and acceptance of the boolean result of `os.execute`. The
  hotfix has entered `main` and appears in a release for the first time; `kpm --version` remains `0.5.0` for now.
- CI fixes and documentation: mandatory argument types, `_` / `__` as a convention,
  the absence of `class`, std patterns, and RU/EN cheat sheets.
- D107–D110 and D113–D115 fix the core/std boundary, range in `gen_list`,
  `show`/`input` patterns, the `std/base` idea, `upk`, the `_`/`__` convention, and the `fn` idea.

## v0.8.0

- Public command `xkraft lint [path...]`: checks indentation, tabs, names,
  `export`, removed builtins, and trailing whitespace according to `docs/style.md`.
  Works with files and directories, on Windows — via PowerShell.
- Fractional range prints `1.0, 1.5, 2.0` instead of `1, 1.5, 2`. Printing of
  ordinary `flint` is unchanged.
- Release `0.7` was skipped: both improvements were combined into `0.8.0`.
- D101 and D102 are fulfilled.

## v0.6.0

- `xkraft --update`: downloads the latest release from GitHub Releases, checks
  `SHA256SUMS`, and atomically replaces the binary. On Windows, files from `kraft-win.zip`
  are updated.
- New version notification: at most once a day, in the terminal only.
  Disabled via `KRAFT_NO_UPDATE_CHECK=1`. On network errors, the check is
  silently skipped.
- `install-auto.sh` uses tag `v0.6.0` by default; if it has not been published
  yet, it falls back to `v0.5.0`.
- D100 is fulfilled. The package registry, website, and AUR package are moved to `1.0`.

## v0.5.0

- Modules and imports: `import_file`, `from_file`, `import_lib`, `from_lib`, and
  `namespace`. `export` is removed: all top-level declarations are importable,
  a `_` prefix does not create privacy.
- The built-in standard library is limited to `std/fos` and `std/cli`.
  `std/fos` — `exists`, `copy`, `remove`, `read_text`, `write_text`, `read_json`,
  `write_json`, `read_csv`, `write_csv` plus `csv_field`, `csv_line`, `csv_parse`;
  `std/cli` — `run` and `kill`. `std/fs`, `std/json`, `std/file`, `std/math`,
  `clamp`, `lerp`, and `is_even` are removed.
- `fib` and `factorial` were moved into the core as built-in functions.
- `flint` accepts an external string without explicit conversion (`input()`,
  `args()`, `read_text()`, CSV) in declarations, assignments, arguments, returns,
  and model fields; a non-numeric value gives `TYPE_MISMATCH_ERROR` at runtime,
  a non-numeric literal is a compile error. `flint(x)` and `str(x)` remain;
  `list()` / `dict()` are not added.
- `kpm` and venv: `kpm init venv` creates `kraft.json`, `kraft.lock`, `venv/`,
  `packages/`, and the compiler in one command, including `venv/bin/xkraft.cmd` on Windows.
  `kpm run` launches a project via venv.
- The dependency section in the manifest is called `deps`; `requirements.txt`
  is not used.
- A `dict` key is `str` or `flint`; `bool`, `NONE`, collections, and models
  cannot be keys.
- Model boundaries are fixed: no inheritance, polymorphism, encapsulation,
  properties, `class`, or operator overloading.
- Output and input are only `show`, `show_err`, `input`.
- Documentation brought up to `0.5.0`: README RU/EN, cheat sheet, builtins, rules,
  decisions, philosophy, install-auto.sh, and dist. It is clarified that JSON
  uses `true`/`false`/`null`.
- Outside `make check`, `dev/tests/stress.sh` was added: built-in and reserved
  names are checked against the documentation, along with self-compilation and
  edge cases of `str` → `flint` conversion. Not included in the distribution.
- A basic style checker `dev/tests/style.sh` and two small example projects
  were added: `mini-calc` (arguments, models, implicit `str` → `flint`) and
  `mini-report` (CSV via `std/fos`). Both non-release scripts are not included
  in `dist`.

Checks: `make check` — 22/22 + 20/20 + 25/25 + 111/111 + 11/11;
`dev/tests/stress.sh` — 12/12, `dev/tests/style.sh` — ok (outside the release).

## v0.4.0

- `..` is the range operator. A range is created in place and has fields `from`,
  `to`, `step`; there is no separate `range r = ...` declaration. The right bound
  is exclusive: `1..5` is `1, 2, 3, 4`. Bounds are always integers, `1..10.0` and
  `1.0..5` give `TYPE_ERROR`; an empty `5..5` is allowed.
- The step sets the mode: `1..10` and `1..10..1` are an integer range,
  `1..10..0.5` is a fractional grid. There are no new numeric types: a number is
  still `flint`. Ranges work in expressions, function arguments, slices (`xs[1..3]`),
  loops (`for i 1..5`), and `in` checks.
- `in` iterates over `list`/`froz` and `dict` keys and checks membership,
  including a half-open interval: `if age in 0..17`. A numeric loop over a range
  is still written without `in`.
- Grouping `trigger CAT1, CAT2:` is one handler for several categories.
  `ANY_ERROR` remains a separate and last branch.
- The core grammar is fixed: modules, imports, `export`, namespaces, and `kpm`
  had been postponed; now they are part of `0.5.0`.
- `dev/xkraft.kraft` is still built by frozen v0.1; tests require byte-for-byte
  matching of Lua from direct and self-built `xkraft`.

Checks: `make check` — 22/22 + 18/18 + 25/25 + 96/96.

## v0.3.0

- Strict falsiness: `if`/`while`, `NOT`/`AND`/`OR`, and `assert` expect `bool`
  or `NONE`. `TRUE` is truthy, `FALSE` and `NONE` are falsy; `0`, `""`, `[]`, `{}`
  give `TYPE_ERROR`. The behavior of frozen v0.1 has not changed.
- `panic("CATEGORY"[, "message"])` — the category is a plain string from a
  known list, and the default message equals the category. It is caught by
  ordinary `trigger CATEGORY` / `trigger ANY_ERROR`.
- Type parameters in `[]` are optional: `list xs` remains an ordinary list,
  while `list[flint]`, `froz[flint]`, `dict[str, flint]` / `dict[str|flint]` specify
  concrete types. Only `str`, `flint`, and `bool` are allowed inside the brackets;
  in `dict` the key type is on the left (always `str`), the value type on the right.
  Nesting, `NONE`, and `froz[list[str]]` are forbidden.
- `froz[T]` is a read-only list: reading, indexing, slicing, and `for in` work;
  writing by index gives `CONST_ERROR`, mutating methods give `NAME_ERROR`;
  a slice preserves `froz` and the specification.
- The Kraft prelude is included without `import`: `prelude_cat`, `path_join`,
  `now_ms`, `parse_args`, `parse_csv`, `parse_json`. In `dist/xkraft` its Lua is
  embedded; `--no-prelude` disables it.
- Windows package: `dist/xkraft-win.lua`, `xkraft.cmd`, `kraft.cmd`,
  `install-win.cmd`, and the `kraft-win.zip` asset. LuaJIT is installed separately.
- The syntax of `try` / `trigger` branches / `finally` has not changed:
  grouping handlers under a common `trigger:` is postponed until the stage of
  modules, imports, and the package manager.
- `dev/xkraft.kraft` is still built by frozen v0.1; type specifications are
  passed in it as strings. Tests require byte-for-byte matching of Lua from
  direct and self-built `xkraft`.

Checks: `make check` — 22/22 + 18/18 + 25/25 + 89/89.

## v0.2.0

The new core model in `xkraft` is enabled by default — no directives, modes,
or switches.

- The top level only declares: reassignment of a global is allowed directly
  in `func`, `for`, `while`; `if`/`elif`/`else` are not change zones
  (`TOPLEVEL_ERROR`).
- Globals without `ext`. Locals, parameters, and `for` counters cannot
  coincide with a global's name (`REDECLARE_ERROR`).
- Type declaration blocks (`str:`, `flint:`, ...) and assignment by index.
- Models: `model`, `method`, `construct`, `self`, `init` — without inheritance.
- Error handling: `try`, `trigger <КАТЕГОРИЯ>`, `ANY_ERROR`, `finally`. The
  `error` object is available in every branch and is read-only;
  `finally` runs on any outcome, including an uncaught error and
  `return`.
- Uppercase names are hard constants (`CONST_ERROR`); occupied names include
  methods of built-in types (`NAME_ERROR`).
- `dev/kraft` remains the frozen v0.1 reference. `dev/xkraft.kraft` builds
  itself; on compatible tests the output matches the reference byte-for-byte.
- `dist/xkraft` is a single self-contained executable with an embedded
  runtime; `make dist` rebuilds it from source.
- Utility files moved to `dev/`: only the main files and the ready `xkraft` remain
  at the root. The v0.1 reference, tests, and self-compilation are there as well.
- `./install.sh` is manual installation, `install-auto.sh` is automatic in one
  command with a privilege prompt. Both install the x binary under the names
  `xkraft` and `kraft`; `kraft` always launches the new model, not the v0.1 reference.
- The error for `show(f(1))` without interpolation is improved: it now
  explicitly says to write `show({f(1)})`.
- Documentation: the Russian README was shortened and rebuilt around examples,
  the English one was expanded. The plan for typed collections `list[T]`,
  `dict[K|V]`, and `froz[T]` is fixed (not yet implemented).

Not included in the release: `froz`, `panic`, stdlib-prelude, modules, imports,
and installation on Windows.

Checks: `make check` — 22/22 + 15/15 + 25/25 + 71/71.

## v0.1.0

Frozen reference compiler on LuaJIT; it lives in `dev/kraft` and is needed
only to build `xkraft.kraft`.

Inside v0.1: types `str`/`flint`/`bool`/`NONE`/`list`/`dict`, indentation,
`$name`/`$(expr)` templates, `show`/`input`, arithmetic
`+ - * / // % **`, comparisons (including chains), `AND`/`OR`/`NOT`, `is`,
`while`/`for`/`for-in` loops, `break`/`continue`, `func`/`return:`,
indexing, `a..b..step` slices, collection methods and built-ins
(`up`, `low`, `title`, `abs`, `round`, `floor`, `ceil`, `sqrt`, `min`,
`max`, `sum`, `avg`, `keys`, `values`, `upk`, `sort`, `reverse`, `clear`,
`find`, `part`, `replace`, `join`, `system`, `assert`, `expect`, `map`,
`filter`, `reduce`). `xkraft.kraft` is written only in this subset: no
`async`, `model`, `try`/`trigger`/`finally`, `froz` or new slice forms.
