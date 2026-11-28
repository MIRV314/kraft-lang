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

## Часть 4. `std/base` — в `0.9.2` и `1.0`

Один встроенный модуль, как `std/math`: `import_lib "std/base"` даёт пространство имён
`base`. Отдельных `std/base/input`, `std/base/oop` и других подмодулей нет.
Модуль реализован досрочно и входит в поставку `0.9.2`.

```kraft
import_lib "std/base"

flint x = base.tern(ok, 1, 2)
```

| Группа | Имена |
| --- | --- |
| Тернар | `tern(cond, a, b)` |
| Строки | `upper`, `lower`, `capwords`, `starts`, `ends`, `has_text`, `find_pos`, `split`, `join_parts`, `trim`, `replace`, `count_text` |
| Печать | `render(value)` |
| Паттерны над `dict` | `make`, `mixin`, `get_field`, `put_field`, `has_field`, `unset_field`, `has_protocol` |

`tern` — обычная функция: обе ветки уже вычислены к моменту вызова, ленивого
тернарного выражения в грамматике нет. Строковые helper'ы — тонкие обёртки над
встроенными `up`, `low`, `title`, `part`, `suff`, `preff`, `find` и методами
строк; `find_pos` возвращает `any`, потому что `find` может дать `NONE`.

`render(value)` печатает `dict` как `{ключ: значение, ...}`, `list` как
`[a, b]`, остальные значения через `str(value)`. `$` в грамматике не
появляется.

ООП-паттерны D123 поверх `model`/`dict`/`self`:

- наследование — композиция: модель хранит родителя полем и явно вызывает его
  методы-обёртками (делегирование);
- полиморфизм — общий протокол из одинаковых имён методов плюс явный
  `is`-диспетчер, потому что метод на `any` вызвать нельзя;
- инкапсуляция — фабричные функции, `_`-имена и accessors; префикс `_` работает
  только как соглашение (D114);
- абстракция — соглашение о протоколе: `has_protocol(obj, names)` проверяет
  нужные ключи у `dict`-объекта;
- примеси — `mixin(base, extra)` и `make(fields)` через `dict.merge`: оба
  возвращают новый словарь.

```kraft
import_lib "std/base"

dict defaults = {kind: "hero"}
dict hero = base.mixin(defaults, {power: 7})
show({base.render(hero)})
```

Это не языковое ООП: нет `extends`, subtyping, приватных полей, dynamic dispatch
и перегрузки операторов; `is` проверяет точный тип модели. Декораторы, `fn` и
нативный многострочный `show()` в `std/base` не кладутся (D105, D115, D123);
многострочный вывод до следующей разморозки пишется через `\n` в строках.

## Часть 5. `std/http` — в `1.1`

Модуль выходит после официального `1.0`, когда async уже вшит в бинарник с
`0.9.2`. Его вызовы приостанавливаемые: внутри `async`-функции они уступают
управление event loop, вне `async` работают синхронно; `get_many` запускает
запросы параллельно. Сейчас `std/http` в поставку не входит.

## Часть 6. Не-std библиотеки

Библиотеки вне ядра пишутся на Kraft и подключаются файлами:

```kraft
import_file "./packages/helpers/main.kraft"
from_file "./packages/helpers/main.kraft" import format_date
```

Каталог `packages/<name>/` остаётся соглашением для таких библиотек;
`kraft.json` и `kraft.lock` в 현재 поставке не используются, реестр пакетов
отложен на отдельный релиз. Версия языка от добавления пользовательской
библиотеки не меняется.
