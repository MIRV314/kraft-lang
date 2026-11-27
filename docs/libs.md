# Библиотеки

Модули стандартной библиотеки вшиты в дистрибутив и подключаются через
`import_lib` или `from_lib`. Имя после `std/` становится пространством имён:
`import_lib "std/math"` даёт `math.pow(...)` и `math.random(...)`.

```kraft
import_lib "std/math"
from_lib "std/fos" import read_text, write_text
```

Полный список того, что доступно без подключения библиотек, — в
[docs/builtins.md](builtins.md). Решения о границе ядро/std — в
[docs/decisions.md](decisions.md) (D94, D95, D119 и D120).

## Часть 1. `std/math`

Добавлена в `0.9.1` решением D120. Две функции:

| Функция | Что делает |
| --- | --- |
| `pow(a, b)` | то же, что встроенный оператор `a ** b` |
| `random(x)` | случайное число из `range` или случайный элемент списка |

### `pow`

```kraft
import_lib "std/math"

show({math.pow(2, 10)})      # 1024
show({math.pow(2.5, 2)})     # 6.25
```

Отрицательное основание с дробным показателем даёт
`VALUE_ERROR: negative number to a fractional power` — как и оператор `**`.

### `random`

Форма с `..` использует уже существующий тип `range` (D87, D88). Правая
граница исключена, шаг задаёт сетку значений. Целый и дробный шаг оба
поддерживаются:

```kraft
import_lib "std/math"

flint n = math.random(1..5)          # одно из 1, 2, 3, 4
flint f = math.random(1..10..0.5)    # одно из 1.0, 1.5, …, 9.5
str answer = math.random(["да", "нет"])
```

Если список пуст — `VALUE_ERROR: empty choice`. Если пуст `range` (например,
`math.random(5..5)`) — `VALUE_ERROR: empty range`, как и было обещано в D87.
Возвращаемое значение `random` имеет тип `any`, поэтому его можно сразу
присважать `flint`, `str` и другим типам; несовместимое значение выявится при
использовании.

Внутри `std/math` вызываются резервированные встроенные функции `rand_num`
для `range` и `rand_choice` для списка. В пользовательском коде они не
импортируются.

В `std/math` пока нет `sin`, `cos`, `tan`, `log`, `clamp`, `lerp` и `is_even`.
Первые четыре отложены, последние три остаются запрещёнными по D95.

## Часть 2. `std/cli`

| Функция | Что делает |
| --- | --- |
| `run(command)` | запустить команду, вернуть код выхода (`-1` при ошибке запуска) |
| `kill(message)` | бросить `VALUE_ERROR` с текстом `message` |

```kraft
import_lib "std/cli"

try:
    cli.kill("стоп")
trigger VALUE_ERROR:
    show("caught: {error.msg}")
```

`run` по действию совпадает со встроенным `system`, но импортируется как
часть библиотеки.

## Часть 3. `std/fos`

«File Operating System» — работа с файлами и форматами:

| Группа | Имена |
| --- | --- |
| Файлы | `exists`, `copy`, `remove`, `read_text`, `write_text` |
| JSON | `read_json`, `write_json` |
| CSV | `read_csv`, `write_csv`, `csv_parse`, `csv_field`, `csv_line` |

```kraft
import_lib "std/fos"

if fos.exists("data.txt"):
    show({fos.read_text("data.txt")})
```

`read_json(path)` → `dict`, `write_json(path, value)` → `bool`. CSV — список
строк; поля разделяются `,`, кавычки внутри поля удваиваются. `csv_parse`
разбирает уже прочитанную строку; `csv_field` и `csv_line` — обычные имена
верхнего уровня.

`json_parse` и `json_stringify` остаются внутренними встроенными функциями и
через `import_lib` не доступны.

## Часть 4. `std/http` — позже

Модуль запланирован на `1.1`, после стабильного `1.0`. Сейчас `std/http` в
поставку не входит.

## Часть 5. Не-std библиотеки

Библиотеки вне ядра пишутся на Kraft и подключаются файлами:

```kraft
import_file "./packages/helpers/main.kraft"
from_file "./packages/helpers/main.kraft" import format_date
```

Каталог `packages/<name>/` остаётся соглашением для таких библиотек;
`kraft.json` и `kraft.lock` в 현재 поставке не используются, реестр пакетов
отложен на отдельный релиз. Версия языка от добавления пользовательской
библиотеки не меняется.
