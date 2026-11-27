# Kraft Code Style

> Russian original: [style.md](style.md). The Russian version is authoritative.

- Indentation is 4 spaces. Tabs and spaces are not mixed within one block.
- One statement per line, `;` is not needed.
- Names are `snake_case`; constants are `UPPER_CASE`; models are `CapWords`.
- The type is always specified at declaration; the type of every function
  argument is mandatory too. `-> type` is added when the result needs to be
  pinned down: recursion, a public API, or non-obvious output.
- `[]` parameters are specified only for specific tasks. Ordinary `list`,
  `dict`, `froz` remain without parameters.
- Strings: double quotes; interpolation is in `show`/`show_err`/`input`. Plain
  strings without substitution are used for error categories, dict keys, and
  `panic` arguments.
- Comments are written in Russian in the compiler and tests; error messages
  are in English, in the format `expected X, found Y`.
- `dev/xkraft.kraft` must be built by frozen v0.1: no new language constructs,
  `|` in expressions, `froz`, `panic`, `try`, or models. Type specifications
  are passed as strings like `"dict[str, flint]"`.
- `_` / `__` before a name is only a convention for the reader: the name remains
  ordinary and importable, creating no privacy.
- For methods with an optional argument, the full form is primary:
  `part(sep, maxsplit)`, `remove(v, count)`. In documentation such an argument
  is marked `?`; in code it is simply omitted: `s.part(",")`,
  `s.remove("x", 2)`.
- One test in `dev/tests/new/` per rule. Success is `<name>.out`; an expected
  return code of 1 additionally has `<name>.code`.
- Lua from direct and self-built `xkraft` must match byte-for-byte.

A basic check of these rules is performed by `dev/tests/style.sh`: tabs,
indentation, names, trailing whitespace, removed keywords and builtins. It is
not part of `make check` and is not included in the distribution; expected test
data (`*.out`, `*.stdin`) and deliberately bad `err_*` fixtures are skipped.
The public command `xkraft lint` is available in `0.8`.
