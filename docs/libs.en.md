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

## Part 4. `std/http` — later

The module is planned for `1.1`, after stable `1.0`. Currently `std/http` is
not in the distribution.

## Part 5. Non-std libraries

Libraries outside the core are written in Kraft and imported by files:

```kraft
import_file "./packages/helpers/main.kraft"
from_file "./packages/helpers/main.kraft" import format_date
```

The `packages/<name>/` directory remains the convention for such libraries;
`kraft.json` and `kraft.lock` are not used in the current distribution, the package
registry is postponed to a separate release. The language version does not change when a user
library is added.
