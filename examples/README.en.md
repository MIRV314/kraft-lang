# Examples

> Russian original: [README.md](README.md). The Russian version is authoritative.

Small complete programs in Kraft. Run from the repository root:

```sh
xkraft examples/hello.kraft                 # the classic "hello"
xkraft examples/features.kraft              # the language in one file
xkraft examples/models.kraft                # models, construct, method
xkraft examples/errors.kraft                # try / trigger / finally
xkraft examples/script.kraft 2 3 4          # arguments and map/filter/reduce
xkraft examples/mini-calc.kraft 2 3 4       # model + implicit str → flint
xkraft examples/mini-report.kraft           # CSV via std/fos
```

Each `.kraft` with a `.out` next to it has the expected output; tests compare them in
`dev/tests/cli.sh`.

Two mini-projects added in `0.5.0`:

| File | What it shows |
| --- | --- |
| [mini-calc.kraft](mini-calc.kraft) | command-line arguments, the `Acc` model, implicit `str → flint` in a method argument |
| [mini-report.kraft](mini-report.kraft) | `from_lib "std/fos"`, `csv_parse`, numeric cells as `flint` |

These are compact demonstrations, not a language showcase. Full example projects
and the package registry are postponed to a separate release after `1.0`.
Fractional range has worked since `0.8.0`: `1.0, 1.5, 2.0` is printed exactly like that.
