# Kraft cheatsheet

One-page reference for v0.2.0. Full docs: [README](../README.md),
[builtins](builtins.md), [decisions](decisions.md).
Russian README: [README.ru](../README.md). English guide:
[README.en](../README.en.md).

## Running

```sh
xkraft file.kraft [args...]         # installed compiler, new model
kraft file.kraft [args...]          # same binary under an alias name
xkraft -c file.kraft                # executable file.lua next to the source
xkraft --tokens file.kraft
xkraft --version                    # xkraft 0.2.0 (both names print this)
```

From a clone use `./xkraft` in the repo root. The frozen v0.1 reference
compiler is kept in `dev/kraft` for development only and is never installed.

Requires `luajit` in `PATH`. Install: `sh install.sh` (into `~/.kraft` and
`~/.local/bin`) or `install-auto.sh` (one command, `/usr/local`, asks for
`sudo`).

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
line, no semicolons. `NONE` is the empty value; only `FALSE` and `NONE` are
falsy. Uppercase names (`MAX`, `MAX_SIZE`) are hard constants: writing to
them is always `CONST_ERROR`.

Types: `str`, `flint`, `bool`, `list`, `dict`, model names. `froz` is reserved
but not implemented. A block of declarations of one type is allowed:

```kraft
str:
    a = "one"
    b = "{a} two"
```

## Operators

- Arithmetic: `+ - * / // % **` (Python semantics: `/` is true division,
  `//` floors, `%` follows the divisor), `-` unary.
- Comparison: `== != < <= > >=`; chained like Python (`0 <= x <= 10`).
- Logic: `AND`, `OR`, `NOT`. Type check: `n is flint`.
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
- `-> type` is optional but checked; recursion requires it.
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

Built-ins: `len`, `type`, `str`, `flint`, `up`, `low`, `title`, `abs`, `round`,
`floor`, `ceil`, `sqrt`, `min`, `max`, `sum`, `avg`, `keys`, `values`, `upk`,
`sort`, `reverse`, `clear`, `map`, `filter`, `reduce`, `read_file`,
`write_file`, `file_exists`, `args`, `exit`, `time_ms`, `is_tty`, `system`,
`assert`, `expect`, `show`, `show_err`, `input`. All names are reserved: a
user declaration cannot reuse a built-in or a method name (`add`, `take`,
`contains`, `count`, `text`, …).

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
parameters; fields declared in the model body are read-only. `init(name: value, ...)`
creates a value by keyword. Uppercase fields are hard constants.

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
trigger ASSERT_ERROR:
    show(caught: {error.msg})
trigger ANY_ERROR:              # must be last
    show(other: {error.cat})
finally:                        # mandatory
    show(always)
```

`error` is read-only: fields `cat`, `msg`, `file`, `line`, `col`, method
`text()`. An error raised inside a `trigger` branch is not caught by the same
block; `break`/`continue` cannot cross a `try` boundary.

Categories: `SYNTAX_ERROR`, `NAME_ERROR`, `REDECLARE_ERROR`, `CONST_ERROR`,
`TOPLEVEL_ERROR`, `TYPE_ERROR`, `SCOPE_ERROR`, `ARGCOUNT_ERROR`,
`VALUE_ERROR`, `CONCATENATE_NOT_SUPPORT`, `FILE_ERROR`,
`TYPE_MISMATCH_ERROR`, `PANIC_ERROR`, `RUNTIME_ERROR`, `GENERATE_ERROR`,
`ASSERT_ERROR`, `EXPECT_ERROR`.

## Not implemented yet

`froz`, `panic`, stdlib prelude, modules (`import_file` / `from_file` /
`import_lib` / `from_lib`), Windows installer. Their names are reserved.
