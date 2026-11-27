# Kraft — шпаргалка

Памятка по `0.9.0`. Полные документы: [README](../README.md),
[builtins](builtins.md), [decisions](decisions.md),
[philosophy](philosophy.md). Английская версия:
[README.en](../README.en.md), [cheatsheet.en](cheatsheet.en.md).

## Запуск

```sh
xkraft file.kraft [args...]         # текущий компилятор, новая модель
xkraft -c file.kraft                # исполняемый file.lua рядом с исходником
xkraft --tokens file.kraft
xkraft --version                    # xkraft 0.9.0
kraft --update                      # обновить бинарник и kpm из GitHub Releases
xkraft lint [path...]               # базовые правила стиля (docs/style.md)
kpm init venv                       # kraft.json, kraft.lock, venv/, packages/
kpm add ./local-package             # зарегистрировать пакет в deps и скопировать в packages/
kpm list
kpm run                             # main.kraft через venv/bin/xkraft
kpm del local-package
kpm --version                       # kpm 1.0.0
```

Из клона используйте `./xkraft` в корне репозитория. Замороженный `kraft` v0.1
лежит в `dev/kraft` только для проверки self-hosting и не ставится. Основной
бинарник — `kraft` (то же самое, что `xkraft`); в установщике он ставится как
`xkraft` плюс псевдоним `kraft`. Команда обновления только одна — `kraft
--update`, обновляет и бинарник, и `kpm`; `kpm update` больше нет.

Нужен `luajit` в `PATH`. Установка: `sh install.sh` (в `~/.kraft` и
`~/.local/bin`) или `install-auto.sh` (одной командой, `/usr/local`, спросит
`sudo`).

На Windows: распакуйте `kraft-win.zip`, запустите `install-win.cmd`; LuaJIT
должен уже быть в `PATH`. И `xkraft.cmd`, и `kraft.cmd` запускают один и тот же
компилятор.

## Синтаксис и значения

```kraft
# комментарий; --- ... --- — многострочный комментарий
str name = "Kraft"          # объявления: тип обязателен
flint n = 3.5               # один числовой тип для целых и дробных
bool ok = TRUE
list xs = [1, 2, 3]
dict cfg = {name: "Kraft"}
show(hello: {name}, n={n})  # интерполяция, не конкатенация
```

Блоки задаются отступами: 4 пробела или табуляции, но не смешивать. Один
оператор на строку, `;` не нужен. `NONE` и `FALSE` — ложь, `TRUE` — истина.
Имена в ВЕРХНЕМ РЕГИСТРЕ (`MAX`, `MAX_SIZE`) — жёсткие константы: запись даёт
`CONST_ERROR`.

Встроенная константа `PI` — число π, пишется без вызова: `show({PI})` →
`3.1415926535898`. Отдельного `std/math` нет.

`flint` принимает строки извне без явного `flint(...)`: `flint age = input()`,
`flint port = args()[1]`. Числовой строковый литерал проверяется при компиляции:
`flint n = "42"` допустимо, `flint n = "x"` даёт `TYPE_ERROR`. Нечисловое
значение извне даёт `TYPE_MISMATCH_ERROR: expected flint, found str: <значение>`
при запуске. Явные `flint(x)` и `str(x)` остаются; `list()` и `dict()` нет.

Идея без срока (D112): `iinput()` без аргументов, подсказка из имени переменной
(`flint age = iinput()` → `age: `). Не добавляется ни в ядро, ни в std.

Типы: `str`, `flint`, `bool`, `list`, `froz`, `dict`, `model`. Допустим блок
объявлений одного типа:

```kraft
str:
    a = "one"
    b = "{a} two"
```

## Операторы

- Арифметика: `+ - * / // % **` (как в Python: `/` — деление, `//` — floor,
  `%` по знаку делителя), унарный `-`.
- Сравнения: `== != < <= > >=`; цепочки как в Python (`0 <= x <= 10`).
- Логика: `AND`, `OR`, `NOT`. Проверка типа: `n is flint`.
- Диапазон: `1..5` даёт `1, 2, 3, 4` (правая граница не входит); `1..10..2`
  шагает по 2, `1..10..0.5` — по 0.5. Границы всегда целые.
- В срезах `..` разделяет границы, `...` задаёт шаг: `xs[..2]` — до индекса 2
  не включительно, `xs[2..]` — до конца, `xs[...2]` — весь список с шагом 2,
  `xs[2...3]` — от 2 до конца с шагом 3, `xs[...]` — копия всего.
- `pass` — пустой оператор в ветке или теле цикла, ничего не делает.
- Вхождение: `if age in 0..17`, `if x in xs`, `if k in d`.
- Строки склеиваются интерполяцией или `xs.join(sep)`, не `+`.
- Составное присваивание: `+= -= *= /= //= %= **=` (только числа).

## Управление

```kraft
if n > 0:
    show(positive)
elif n == 0:
    show(zero)
else:
    show(negative)

for i 5:                    # 0, 1, 2, 3, 4
    show({i})
for i 5..9:                 # 5..8, правая граница не входит
for i 10..0..-2:            # шаг задаёт направление
for x in xs:                # перебор элементов
while n > 0:
    n -= 1
    if n == 3:
        break
    else:
        pass                # пустая ветка, разрешена
```

## Функции и глобальные переменные

```kraft
func add(flint a, flint b) -> flint:
    return a + b
```

- `func` только на верхнем уровне; вложенных функций нет. Функция видна
  только после объявления.
- Тип каждого аргумента обязателен. `-> type` опционально, но проверяется;
  для рекурсии и публичного API он нужен.
- Функция видит глобальные переменные файла. В `xkraft` верхний уровень только
  объявляет: переприсваивать глобалы можно непосредственно внутри `func`,
  `for` или `while`, но не на простой строке верхнего уровня и не внутри
  `if`/`elif`/`else` (`TOPLEVEL_ERROR`). Ключевого слова `ext` нет.
- Локальные переменные, параметры и счётчики `for` не могут перекрывать
  глобал (`REDECLARE_ERROR`).

## Коллекции

```kraft
list xs = [3, 1, 2]
xs.add(4)
xs.del(0)
show({xs.contains(2)})      # TRUE
show({map(xs, double)})     # функция по имени, лямбд нет
show({filter(xs, even)})
show({reduce(xs, plus, 0)})
show({xs[0]})               # срезы: s[2..7], xs[..5], xs[1..5..2], xs[...2]
xs[0] = 10                  # после v0.1: присваивание по индексу
```

Параметры `[]` необязательны и нужны только для конкретных задач:

```kraft
list nums = [1, 2, 3]
list[flint] ints = [1, 2, 3]
dict[str|flint] cfg = {"age": 25}   # dict[str, flint] — то же самое
froz[flint] frozen = [4, 5]         # только для чтения
```

Внутри `[]`: только `str`, `flint`, `bool`; без вложенности и `NONE`. В `dict`
левый тип — ключ (`str` или `flint`), правый — значение. Голое имя равно
строке в кавычках. `froz` поддерживает чтение, срезы и `for in`; запись и
изменяющие методы — ошибка.

Prelude доступен без `import`: `prelude_cat`, `path_join`, `now_ms`,
`parse_args`, `parse_csv`, `parse_json`. Отключается флагом `--no-prelude`.

Встроенные: `len`, `type`, `str`, `flint`, `up`, `low`, `title`, `abs`, `round`,
`floor`, `ceil`, `sqrt`, `factorial`, `fib`, `PI`, `min`, `max`, `sum`, `avg`, `keys`,
`values`, `upk`, `sort`, `reverse`, `clear`, `map`, `filter`, `reduce`,
`read_file`, `write_file`, `file_exists`, `args`, `exit`, `time_ms`, `is_tty`,
`system`, `assert`, `expect`, `show`, `show_err`, `input`. Вывод и ввод — только
`show` / `show_err` / `input`.

`keys(d)` и `values(d)` возвращают новые списки ключей и значений. `upk(coll)`
даёт содержимое без внешних скобок: `[1, "два"]` → `1, "два"`; по D113
планируется убрать запятые (`1 "два"`). Знак `?` в документации означает
необязательный аргумент; в код его не пишут: `s.part(",")`, `s.remove("x")`.

Все имена зарезервированы: пользовательское объявление не может повторить
встроенное имя или имя метода (`add`, `take`, `contains`, `count`, `text`, …).

## Модели (xkraft)

```kraft
model Counter:
    construct(flint value):
        self(value)             # создаёт поле value
    method inc(flint by) -> flint:
        self.value = self.value + by
        return self.value

Counter c = Counter(5)
show({c.inc(3)})                # 8
show({c is Counter})            # TRUE
```

Поля создаются в `construct`: `self(a, b)` создаёт поля по именам параметров;
запись `self.hp = 100` меняет уже существующее поле. `class` не вводится —
`model` выполняет его роль. Наследование и полиморфизм живут как паттерны в
std, не как языковая ООП.

## Ошибки

Ошибки времени компиляции показывают категорию, файл, строку, исходник и
каретку:

```
CONST_ERROR: file.kraft:3
    3 | MAX = 5
              ^ expected mutable target, found constant 'MAX'
```

Ошибки времени выполнения перехватываются в `xkraft`:

```kraft
try:
    assert(FALSE, "bad")
trigger ASSERT_ERROR, VALUE_ERROR:  # один обработчик на обе
    show(caught: {error.cat})
trigger ANY_ERROR:              # должен быть последним
    show(other: {error.cat})
finally:                        # обязателен
    show(always)
```

`error` доступен только для чтения: поля `cat`, `msg`, `file`, `line`, `col`,
метод `text()`. Ошибка, поднятая внутри ветки `trigger`, тем же блоком не
ловится; `break`/`continue` не могут пересекать границу `try`.

`panic("CATEGORY"[, "message"])` поднимает известную категорию; без сообщения
категория становится `error.msg`. Ловится `trigger CATEGORY` или
`trigger ANY_ERROR` так же, как ошибка времени выполнения.

Категории: `SYNTAX_ERROR`, `NAME_ERROR`, `REDECLARE_ERROR`, `CONST_ERROR`,
`TOPLEVEL_ERROR`, `TYPE_ERROR`, `SCOPE_ERROR`, `ARGCOUNT_ERROR`,
`VALUE_ERROR`, `CONCATENATE_NOT_SUPPORT`, `FILE_ERROR`,
`TYPE_MISMATCH_ERROR`, `PANIC_ERROR`, `RUNTIME_ERROR`, `GENERATE_ERROR`,
`ASSERT_ERROR`, `EXPECT_ERROR`.

## Модули, stdlib и пакеты (0.5)

`import_file` / `from_file` работают с локальными файлами, `import_lib` /
`from_lib` — со встроенными библиотеками; `namespace` группирует объявления.
Все имена верхнего уровня импортируемы. Префикс `_` или `__` — только
соглашение для читающего, приватности он не создаёт.

```kraft
import_lib "std/fos"
from_lib "std/fos" import read_json, write_csv
import_lib "std/cli"
```

`std/fos` — «File Operating System»: `exists`, `copy`, `remove`, `read_text`,
`write_text`, `read_json`, `write_json`, `read_csv`, `write_csv`, плюс
`csv_field`, `csv_line`, `csv_parse`. В `std/cli` только `run` и `kill`.
`system(command)` — встроенный запуск через `/bin/sh -c`; `cli.run(command)` —
обёртка в `std/cli`; оба возвращают код выхода.

`std/fs`, `std/json`, `std/math`, `clamp`, `lerp` и `is_even` не поставляются;
`fib` и `factorial` — встроенные функции.

```sh
kpm init venv        # kraft.json, kraft.lock, venv/, packages/
kpm add ./pkg        # локальный путь или URL
kpm list
kpm run
kpm del pkg
# обновление: kraft --update (бинарник и kpm вместе, с проверкой SHA256SUMS)
```
