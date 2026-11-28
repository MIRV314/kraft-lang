# Libraries

> [Russian original: libs.md](libs.md) — the Russian version is authoritative.

Standard library modules are built into the distribution and imported via
`import_lib` or `from_lib`. The name after `std/` becomes the namespace:
`import_lib "std/math"` gives `math.pow(...)` and `math.random(...)`.

```kraft
import_lib "std/math"
from_lib "std/fos" import read_text, write_text
```

The full list of what is available without importing libraries is in
[docs/builtins.md](builtins.md). Decisions about the core/std boundary are in
[docs/decisions.md](decisions.md) (D94, D95, D119, and D120).

## Part 1. `std/math`

Added in `0.9.1` by decision D120. Two functions:

| Function | What it does |
| --- | --- |
| `pow(a, b)` | same as the built-in operator `a ** b` |
| `random(x)` | a random number from `range` or a random element of a list |

### `pow`

```kraft
import_lib "std/math"

show({math.pow(2, 10)})      # 1024
show({math.pow(2.5, 2)})     # 6.25
```

A negative base with a fractional exponent gives
`VALUE_ERROR: negative number to a fractional power` — same as the `**` operator.

### `random`

The form with `..` uses the already existing `range` type (D87, D88). The right
bound is exclusive, the step defines the value grid. Both integer and fractional steps are
supported:

```kraft
import_lib "std/math"

flint n = math.random(1..5)          # одно из 1, 2, 3, 4
flint f = math.random(1..10..0.5)    # одно из 1.0, 1.5, …, 9.5
str answer = math.random(["да", "нет"])
```

If the list is empty — `VALUE_ERROR: empty choice`. If the `range` is empty (for example,
`math.random(5..5)`) — `VALUE_ERROR: empty range`, as promised in D87.
The value returned by `random` has type `any`, so it can be assigned right away
to `flint`, `str`, and other types; an incompatible value will show up when
used.

Inside `std/math`, the reserved builtins `rand_num` for `range` and
`rand_choice` for lists are called. In user code they are not
imported.

`std/math` does not yet have `sin`, `cos`, `tan`, `log`, `clamp`, `lerp`, and `is_even`.
The first four are postponed, the last three remain forbidden per D95.

## Part 2. `std/cli`

| Function | What it does |
| --- | --- |
| `run(command)` | run a command, return the exit code (`-1` if launch fails) |
| `kill(message)` | raise `VALUE_ERROR` with the text `message` |

```kraft
import_lib "std/cli"

try:
    cli.kill("стоп")
trigger VALUE_ERROR:
    show("caught: {error.msg}")
```

`run` is identical in effect to the built-in `system`, but is imported as
part of the library.

## Part 3. `std/fos`

"File Operating System" — work with files and formats:

| Group | Names |
| --- | --- |
| Files | `exists`, `copy`, `remove`, `read_text`, `write_text` |
| JSON | `read_json`, `write_json` |
| CSV | `read_csv`, `write_csv`, `csv_parse`, `csv_field`, `csv_line` |

```kraft
import_lib "std/fos"

if fos.exists("data.txt"):
    show({fos.read_text("data.txt")})
```

`read_json(path)` → `dict`, `write_json(path, value)` → `bool`. CSV is a list
of rows; fields are separated by `,`, quotes inside a field are doubled. `csv_parse`
parses an already read string; `csv_field` and `csv_line` are ordinary top-level
names.

`json_parse` and `json_stringify` remain internal builtins and are not available
through `import_lib`.

## Part 4. `std/base` — in `0.9.2` and `1.0`

One built-in module, like `std/math`: `import_lib "std/base"` gives the `base`
namespace. There are no `std/base/input`, `std/base/oop` or other submodules.
The module is implemented ahead of schedule and ships in `0.9.2`.

```kraft
import_lib "std/base"

flint x = base.tern(ok, 1, 2)
```

| Group | Names |
| --- | --- |
| Ternary | `tern(cond, a, b)` |
| Strings | `upper`, `lower`, `capwords`, `starts`, `ends`, `has_text`, `find_pos`, `split`, `join_parts`, `trim`, `replace`, `count_text` |
| Printing | `render(value)` |
| Patterns over `dict` | `make`, `mixin`, `get_field`, `put_field`, `has_field`, `unset_field`, `has_protocol` |

`tern` is an ordinary function: both branches are already evaluated at the call
site; there is no lazy ternary expression in the grammar. The string helpers are
thin wrappers over the built-ins `up`, `low`, `title`, `part`, `suff`, `preff`,
`find` and string methods; `find_pos` returns `any` because `find` may produce
`NONE`.

`render(value)` prints a `dict` as `{key: value, ...}`, a `list` as `[a, b]`,
and other values through `str(value)`. No `$` enters the grammar.

The OOP patterns from D123 over `model`/`dict`/`self`:

- inheritance — composition: a model stores the parent in a field and calls its
  methods through explicit wrappers (delegation);
- polymorphism — a shared protocol of identical method names plus an explicit
  `is` dispatcher, because a method call on `any` is forbidden;
- encapsulation — factory functions, `_` names and accessors; the `_` prefix is
  only a convention (D114);
- abstraction — an agreed protocol: `has_protocol(obj, names)` checks the
  required keys of a `dict`-based object;
- mixins — `mixin(base, extra)` and `make(fields)` through `dict.merge`; both
  return a new dict.

```kraft
import_lib "std/base"

dict defaults = {kind: "hero"}
dict hero = base.mixin(defaults, {power: 7})
show({base.render(hero)})
```

This is not language-level OOP: there is no `extends`, subtyping, private
fields, dynamic dispatch or operator overloading; `is` checks the exact model
type. Decorators, `fn` and native multiline `show()` are not put into
`std/base` (D105, D115, D123); until the next grammar unfreeze, multiline output
is written with `\n` in strings.

## Part 5. `std/http` — in `1.1`

The module ships after the official `1.0`, when async is already built into the
binary from `0.9.2`. Its calls are suspendable: inside an `async` function they
yield to the event loop, outside `async` they are synchronous; `get_many` runs
requests in parallel. Currently `std/http` is not in the distribution.

## Part 6. Non-std libraries

Libraries outside the core are written in Kraft and imported by files:

```kraft
import_file "./packages/helpers/main.kraft"
from_file "./packages/helpers/main.kraft" import format_date
```

The `packages/<name>/` directory remains the convention for such libraries;
`kraft.json` and `kraft.lock` are not used in the current distribution, the package
registry is postponed to a separate release. The language version does not change when a user
library is added.
