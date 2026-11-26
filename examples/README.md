# Примеры

Небольшие законченные программы на Kraft. Запуск из корня репозитория:

```sh
xkraft examples/hello.kraft                 # классический «привет»
xkraft examples/features.kraft              # язык за один файл
xkraft examples/models.kraft                # модели, construct, method
xkraft examples/errors.kraft                # try / trigger / finally
xkraft examples/script.kraft 2 3 4          # аргументы и map/filter/reduce
xkraft examples/mini-calc.kraft 2 3 4       # модель + неявное str → flint
xkraft examples/mini-report.kraft           # CSV через std/fos
```

Каждый `.kraft` рядом с `.out` — это ожидаемый вывод; тесты сверяют их в
`dev/tests/cli.sh`.

Два мини-проекта, добавленные в `0.5.0`:

| Файл | Что показывает |
| --- | --- |
| [mini-calc.kraft](mini-calc.kraft) | аргументы командной строки, модель `Acc`, неявное `str → flint` в аргументе метода |
| [mini-report.kraft](mini-report.kraft) | `from_lib "std/fos"`, `csv_parse`, числовые ячейки как `flint` |

Это компактные демонстрации, а не витрина языка. Полноценные проекты-примеры
запланированы перед `1.0`: к тому времени добавятся реестр пакетов и обновлённый
формат дробного range.
