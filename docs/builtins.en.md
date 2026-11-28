# Core builtins

> [Russian original: builtins.md](builtins.md) — the Russian version is authoritative.

The canonical list of what is available in any `.kraft` file without
importing libraries. All of it is part of the compiler and runtime core.
Optional add-ons (paths, dates, CLI, test runner) are not included in
this list.

`NONE` can be passed as any argument; the type check happens at the point of
use. Type errors are `TYPE_ERROR` at compile time where the type
is known, otherwise `TYPE_MISMATCH_ERROR` at runtime.

The core/std boundary is fixed in D119 and refined in D120: everything listed
below is core; the std modules are `std/fos`, `std/cli`, and `std/math`.
The prelude is imported automatically; `--no-prelude` disables it.

## Global functions

| Group | Calls |
| --- | --- |
| Checks and size | `len(x)`, `type(x)`, `str(x)`, `flint(x)` |
| Strings | `up(s)`, `low(s)`, `title(s)` |
| Numbers | `abs(n)`, `round(n)`, `floor(n)`, `ceil(n)`, `sqrt(n)`, `factorial(n)`, `fib(n)`, `min(...)`, `max(...)` |
| Collections | `sum(xs)`, `avg(xs)`, `keys(d)`, `values(d)`, `upk(coll)`, `sort(xs)`, `reverse(xs)`, `clear(coll)` |
| Higher-order functions | `map(xs, f)`, `filter(xs, f)`, `reduce(xs, f, start)` |
| Files | `read_file(path)`, `write_file(path, text)`, `file_exists(path)` |
| Process | `args()`, `exit(code)`, `time_ms()`, `is_tty()`, `system(command)`, `timer(ms, value)` |
| Tests | `assert(condition, message)`, `expect(value)` |
| Printing and input | `show(template)`, `show_err(template)`, `input(prompt)` |
| Constant | `PI` |

### Checks and conversions

- `len(x)` — `str`: UTF-8 characters; `list`: elements; `dict`: keys.
  Anything else — `TYPE_MISMATCH_ERROR`.
- `type(x)` — type name as text: `"str"`, `"flint"`, `"bool"`, `"list"`,
  `"froz"`, `"dict"`, `"range"`, `"func"`, `"NONE"`, and model names.
- `str(x)` — text of the value, as when printed.
- `flint(x)` — number as is, `bool` → `1`/`0`, `str` → parse;
  an unparsed string and an incompatible type — `TYPE_MISMATCH_ERROR`.
- A string from outside (`input()`, `args()`, `read_text()`, a `read_csv()` cell) can
  be assigned to `flint` without a call: the compiler inserts the same conversion.
  A numeric string literal (`flint n = "42"`) is accepted at compile time,
  a non-numeric one (`flint n = "x"`) — `TYPE_ERROR`. `list()` and `dict()` as
  casts do not exist.

### Strings

- `up(s)` / `low(s)` — upper/lower case for Latin and Latin-1;
  Cyrillic is unchanged.
- `title(s)` — each word capitalized, the rest lowercase.

### Numbers

- `PI` — built-in `flint` constant, the number π (`3.1415926535898` when printed).
  Written without a call: `show({PI})`. Math add-ons are in
  `std/math` (D120).
- `abs(n)` — absolute value.
- `round(n)` — round to nearest, halves away from zero:
  `2.5 → 3`, `-2.5 → -3`.
- `floor(n)` / `ceil(n)` — down / up.
- `sqrt(n)` — square root; a negative number — `VALUE_ERROR`.
- `factorial(n)` — product `1..n`; `n <= 1` gives `1`.
- `fib(n)` — Fibonacci numbers: `fib(0) = 0`, `fib(1) = 1`; for `n <= 1`
  it returns `n`.
- `min(...)` / `max(...)` — from 1 to 9 arguments. A single list argument —
  the minimum/maximum of its elements; otherwise all arguments must be
  `flint`. An empty list — `VALUE_ERROR`.

### Collections

- `sum(xs)` — sum of numbers, empty list → `0`; elements are checked.
- `avg(xs)` — average; empty list — `VALUE_ERROR`.
- `keys(d)` → new list of keys; `values(d)` → new list of values.
  For example, for `{name: "Kraft"}` these are `["name"]` and `["Kraft"]`. This is not
  unpacking: the source dict is unchanged.
- `upk(coll)` — contents without outer brackets: `[1, "два"]` → `1, "два"`,
  a dict → `имя: "Kraft"`. The separator is `", "`. Per D113 it is planned to remove
  the commas and use a space; until implemented, the current output is described.
- `sort(xs)` → **new** list in ascending order; numbers only. The source is
  unchanged.
- `reverse(xs)` → **new** list in reverse order.
- `clear(coll)` — clears a list or dict **in place**, returns
  `NONE`.

### Higher-order functions

A function is passed **by name**, there are no lambdas: `map(xs, double)`. If lambdas
ever appear, the keyword will be `fn`, not `lambda` (D115).

- `map(xs, f)` → new list of results of `f(x)`.
- `filter(xs, f)` → new list of elements for which `f(x)` is truthy.
- `reduce(xs, f, start)` — fold: `f(аккумулятор, x)`.
- `f` must be declared earlier and have the required arity: 1 for
  `map`/`filter`, 2 for `reduce`. Incorrect arity — `ARGCOUNT_ERROR`.

### Files and process

- `read_file(path)` — the whole file; no file — `FILE_ERROR`.
- `write_file(path, text)` — overwrite completely, `bool`; error —
  `FILE_ERROR`.
- `file_exists(path)` → `bool`.
- `args()` → `list[str]`: `[0]` is the path to the source, followed by the arguments.
- `exit(code)` — terminate the program.
- `time_ms()` — processor time in milliseconds.
- `is_tty()` — `TRUE` if stderr is a terminal.
- `system(command)` — run via `/bin/sh -c`; exit code `0..255`,
  on a signal — `128 + number`, failed to start — `-1`. Built-in, available without
  import; `cli.run(command)` from `std/cli` is a thin wrapper over the same
  mechanism.
- `timer(ms, value)` — the suspendable test operation from D106: it yields to
  the event loop for `ms` milliseconds of wall-clock time and returns `value`.
  The whole program runs inside the loop; inside an `async` function the timer
  suspends that function only, and parallel calls are awaited together.
  There is no timer error; `ms < 0` is treated as zero. Input, files and
  `system()` remain blocking.

### Tests

- `assert(condition, message)` — if the condition is false, `ASSERT_ERROR` with
  the text `message`.
- `expect(value)` → a value of internal type `expect` with methods:
  - `.equals(x)` — equal;
  - `.is_true()` / `.is_false()`;
  - `.is_none()`;
  - `.contains(x)` — for a string, list, or dict.
  On failure — `EXPECT_ERROR`; on success — `NONE`.

## Prelude (available without import)

Prelude is not part of the frozen core v0.1, but it is added to every
`xkraft` program by default. The `--no-prelude` flag disables it.

| Call | What it does |
| --- | --- |
| `prelude_cat(xs)` | concatenate a list of strings without a separator |
| `path_join(a, b)` | join path parts with `/`, without doubling the slash |
| `now_ms()` | same as `time_ms()` |
| `parse_args()` | parse `args()[1..]`: `--k=v` → key `k`, `--k` → `"TRUE"`, positional → keys `"1"`, `"2"`, … |
| `parse_csv(data)` | lines split by `\n`, empty ones skipped, fields split by `,` |
| `parse_json(data)` | compact object parsing: string, numeric, and `true`/`false`/`null` values; not an object → `TYPE_ERROR`, parse error → `VALUE_ERROR` |

Prelude function names are reserved just like builtins (D79).

## Reserved but not public

These names are occupied by the compiler: they cannot be used for your own variables,
functions, and models. Ordinary programs do not need them — they are called by `std/fos`
or the compiler itself.

| Name | What it does | Why it is not in the public API |
| --- | --- | --- |
| `copy_file(src, dst)` | copy a file | `fos.copy` exists |
| `remove_file(path)` | remove a file | `fos.remove` exists |
| `json_parse(text)`, `json_stringify(value)` | parse and write JSON | `fos.read_json` / `fos.write_json` exist |
| `raise(category, message)` | raise an error directly | `panic` and `try`/`trigger`/`finally` exist |

The keyword `glob` is also reserved but is not used in `xkraft`:
global variables are changed directly inside `func`, `for`, and `while`, without
`glob`. In v0.1 it existed for function isolation and remains in the history of the language.

## Standard library

Four modules are built into the working `0.9.3` distribution and imported via
`import_lib` / `from_lib`:

| Module | Names |
| --- | --- |
| `std/fos` | `exists`, `copy`, `remove`, `read_text`, `write_text`, `read_json`, `write_json`, `read_csv`, `write_csv`, `csv_field`, `csv_line`, `csv_parse` |
| `std/cli` | `run`, `kill` |
| `std/math` | `pow`, `random` |
| `std/base` | `tern`, string helpers, `render`, patterns over `dict` |

`std/base` (D110, D123) is implemented ahead of schedule and ships in `0.9.2`
and `1.0`: `tern`, string helpers, `render`, and OOP patterns over
`model`/`dict`/`self`. `std/http` follows in `1.1`, immediately async-aware
(D104). The published `0.9.1` distribution contains only the first three
modules.

- `fos.exists(path)`, `fos.copy(src, dst)`, `fos.remove(path)` → `bool`.
- `fos.read_text(path)` → `str`; `fos.write_text(path, data)` → `bool`.
- `fos.read_json(path)` → `dict`; `fos.write_json(path, value)` → `bool`.
- `fos.read_csv(path)` → list of strings; `fos.write_csv(path, rows)` → `bool`.
  Fields are separated by `,`, quotes inside a field are doubled. `csv_parse(data)`
  parses a string; `csv_field` and `csv_line` are ordinary top-level names.
- `cli.run(command)` → exit code (`-1` if it could not be started); in effect it
  matches the built-in `system`, but it is imported from `std/cli`.
  `cli.kill(message)` raises `VALUE_ERROR`.
- `math.pow(a, b)` — same as the `**` operator.
- `math.random(x)` — if `x` is a `range`, returns a random value on its
  grid; if `x` is a list, returns a random element. Details are in
  [docs/libs.md](libs.md).
- `base.tern(cond, a, b)` — eager ternary helper; `base.upper`, `base.lower`,
  `base.capwords`, `base.starts`, `base.ends`, `base.has_text`,
  `base.find_pos`, `base.split`, `base.join_parts`, `base.trim`,
  `base.replace`, `base.count_text` — string helpers; `base.render(value)`
  prints dicts, lists and scalars; `base.make`, `base.mixin`,
  `base.get_field`, `base.put_field`, `base.has_field`, `base.unset_field`,
  `base.has_protocol` — patterns over `dict`. The full list is in
  [docs/libs.md](libs.md).

`json_parse`, `json_stringify`, `rand_num`, and `rand_choice` remain internal
builtins and are not imported: `std/math` calls them itself. `std/fs`,
`std/json`, `std/file`, as well as `clamp`, `lerp`, and `is_even` are not in the distribution.

## String methods

| Method | What it does |
| --- | --- |
| `s.part()` | split on spaces, empty chunks discarded |
| `s.part(sep)` | split on the separator; empty `sep` — `VALUE_ERROR` |
| `s.part(sep, maxsplit)` | at most `maxsplit` splits; `maxsplit < 0` — no limit |
| `s.find(sub)` | index of the first occurrence or `NONE` |
| `s.contains(sub)` | `TRUE` if the substring is present |
| `s.preff(p)` / `s.suff(p)` | starts / ends with `p` |
| `s.trim(chars?)` | remove characters from both sides; whitespace by default |
| `s.triml(chars?)` / `s.trimr(chars?)` | only on the left / only on the right |
| `s.replace(old, new)` | replace all occurrences; `old == ""` → no change |
| `s.remove(sub, count?)` | remove occurrences: without `count` — all, with `count` — at most |
| `s.count(sub)` | number of non-overlapping occurrences |

The full form with the optional argument is primary: `s.part(sep, maxsplit)`,
`s.remove(sub, count)`. The `?` in the table means the argument may be omitted:
`s.part(",")`, `s.remove("x")` are correct code; `?` is not written in code.

A substring is only via a slice: `s[2..7]`, `s[..5]`, `s[7..]`, `s[...2]`,
`s[1...]`. Indices and lengths are in UTF-8 characters, zero-based.

## List methods

| Method | What it does |
| --- | --- |
| `xs.add(v)` | append to the end |
| `xs.add(i, v)` | insert before index `i` |
| `xs.del()` | remove the last element |
| `xs.del(i)` | remove by index |
| `xs.remove(v)` | remove all occurrences, `bool` |
| `xs.remove(v, count)` | remove at most `count` occurrences, `bool` |
| `xs.replace(i, v)` | replace element by index |
| `xs.replace_value(a, b)` | replace the first occurrence of value `a` with `b`, `bool` |
| `xs.contains(v)` / `xs.count(v)` | whether present / how many times |
| `xs.index(v)` | index of the first occurrence or `NONE` |
| `xs.join(sep)` | elements via `str`, separator `str` |

The full form `xs.remove(v, count)` is primary; `xs.remove(v)` is the short form
without `count`.

`replace(i, v)` remains replacement by index: the bootstrap of
`xkraft` depends on it. Value replacement is `replace_value(a, b)`.

## Dict methods

| Method | What it does |
| --- | --- |
| `d.add(k, v)` | add or replace a pair |
| `d.take(k)` | value or `NONE` |
| `d.remove(k)` | remove a key, `bool` |
| `d.contains(k)` | whether the key is present |
| `d.merge(other)` | **new** dict: pairs of `d`, then `other` on top |

A key is `str` or `flint`. In `[]` it is written as a bare name or a string
literal: `d[имя]` ≡ `d["имя"]`. `bool`, `NONE`, collections, and models cannot
be keys. A dynamic key is `d.take(k)` and `d.add(k, v)`.

## Indices and assignment

```kraft
xs[0]          # чтение
xs[-1]         # с конца
xs[1..5..2]    # срез, правая граница не входит
xs[2...3]      # от 2 до конца, шаг 3
xs[0] = 99     # запись
d[ключ] = 1    # запись по литеральному ключу
```

In slices `..` separates bounds, `...` sets the step. This is the same style as
`for i a..b..step`.
For `xs = [10, 20, 30, 40, 50]`:

| Notation | What it gives |
| --- | --- |
| `xs[..2]`, `xs[1..4]` | up to index 2 / from 1 to 4; right bound is exclusive |
| `xs[2..]`, `xs[..]` | from 2 to end / copy of everything |
| `xs[2...3]`, `xs[2...]` | from 2 to end with step 3 / with step 1 |
| `xs[...2]`, `xs[...]` | whole list with step 2 / copy of everything |
| `xs[1..4..2]`, `xs[4...-2]` | step to the right / step to the left |

- A list index is `flint`; a negative one counts from the end.
- Out of bounds — `VALUE_ERROR`; slice step `0` — `VALUE_ERROR`.
- There are no `...` forms in loops: `for` has no implicit right bound.
- Strings are immutable: `s[0] = "x"` — `TYPE_ERROR`.
- For `any` (reading from an untyped collection), the check happens at runtime.

`pass` is the empty statement, included in D118; it is not used in slices or expressions.
