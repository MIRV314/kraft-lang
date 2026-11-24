# Kraft

[![CI](https://github.com/MIRV314/kraft-lang/actions/workflows/ci.yml/badge.svg)](https://github.com/MIRV314/kraft-lang/actions/workflows/ci.yml)
[![release v0.4.0](https://img.shields.io/badge/release-v0.4.0-blue.svg)](https://github.com/MIRV314/kraft-lang/releases/tag/v0.4.0)

[English](README.en.md) · [Шпаргалка](docs/cheatsheet.md) · [Встроенные](docs/builtins.md) · [Release](https://github.com/MIRV314/kraft-lang/releases/tag/v0.4.0)

Kraft — статически типизированный язык: один числовой тип `flint`, отступы
вместо фигурных скобок, интерполяция `{}` вместо склейки строк. Ядро маленькое
и заморожено; всё остальное растёт библиотекой на самом Kraft. Компилятор
`xkraft` тоже написан на Kraft и собирает сам себя.

- **Одна команда.** `.kraft` → Lua → LuaJIT. Никакого C и никакой сборки.
- **Один бинарник.** После установки `xkraft` и `kraft` — два имени одного
  x-бинарника; замороженный v0.1 в систему не ставится.
- **Один язык для всего.** Ядро, примеры и сам компилятор — на Kraft.

## Быстрый старт

Нужна только LuaJIT (`luajit` в `PATH`):

```sh
curl -fsSL https://raw.githubusercontent.com/MIRV314/kraft-lang/main/install-auto.sh | sh
```

Или из клона: `sh install.sh` — по умолчанию в `~/.local/bin`.

```sh
xkraft --version                    # xkraft 0.4.0
kraft --version                     # то же самое: псевдоним

xkraft program.kraft                # скомпилировать и запустить
kraft program.kraft                 # то же самое
xkraft -c program.kraft             # собрать program.lua рядом
xkraft --tokens program.kraft       # посмотреть токены
xkraft program.kraft 1 2 3          # аргументы программы
```

Из корня клона бинарник лежит рядом: `./xkraft examples/features.kraft`.

## Язык за пять минут

### Переменные, типы, вывод

```kraft
str name = "Kraft"
flint version = 3
show(язык: {name} версия: {version})    # язык: Kraft версия: 3

flint MAX = 100                         # имя капсом — константа
```

Тип при объявлении обязателен, при присваивании не повторяется.

| Тип | Пример |
| --- | --- |
| `str` | `"текст"`, `'текст'` |
| `flint` | `42`, `-7`, `3.5` — одно число на целые и дробные |
| `bool` | `TRUE`, `FALSE` |
| `list` | `[1, 2, 3]` |
| `dict` | `{имя: "Kraft", возраст: 25}` |
| `froz` | `[4, 5, 6]` — только для чтения |
| `model` | `Counter(5)` |

`NONE` может быть ложью, `FALSE` — ложь, `TRUE` — истина.

```kraft
show(привет, {name}!)       # привет, Kraft!
show({version + 1})         # 4
show(\{x\})                 # {x}
```

Если вместо `show({f(1)})` написать `show(f(1))`, компилятор подскажет,
куда поставить фигурные скобки.

### Функции, условия, циклы

```kraft
func summ(flint a, flint b) -> flint:
    return a + b

flint n = summ(2, 3)
if n > 4:
    show(big: {n})
elif n == 4:
    show(four)
else:
    show(small: {n})

for i 1..5:                 # 1, 2, 3, 4
    show({i})

flint i = 0
while i < 3:
    i += 1
```

`-> тип` — аннотация, опциональное указание типа результата. Можно не писать:
компилятор выведет тип из `return`. Для рекурсии аннотация обязательна.

```kraft
func inc(flint n):              # без аннотации — тип будет выведен
    return n + 1

func dec(flint n) -> flint:     # аннотация задана явно
    return n - 1
```

Функция видна только после объявления. Условия используют `AND`, `OR`, `NOT`;
сравнения можно цеплять: `0 <= x <= 10`.

`..` задаёт диапазон с исключённой правой границей; отдельного объявления
`range` нет — диапазон пишется сразу на месте. Границы всегда целые, шаг
может быть дробным:

```kraft
for i 1..5:                 # 1, 2, 3, 4
    show({i})
for x 1..10..0.5:           # 1, 1.5, 2, …, 9.5
    show({x})
show({xs[1..3]})            # срез: элементы 1 и 2
if age in 0..17:            # вхождение в полуоткрытый интервал
    show(child)
```

`in` перебирает `list`/`froz` и ключи `dict` (`for x in xs`, `for k, v in d`)
или проверяет вхождение. В числовом цикле по диапазону `in` не пишется.

### Глобальные переменные в `xkraft`

Верхний уровень только объявляет. Писать в глобальную можно непосредственно
в `func`, `for` или `while`; `if`/`elif`/`else` зоной изменений не являются.

```kraft
flint total = 0

func add_points(flint n):
    total += n              # без ext

for i 10:
    total += i              # цикл тоже зона изменений

add_points(10)
show({total})               # 55
```

Локальные переменные, параметры и счётчики `for` не могут совпадать с именем
глобальной (`REDECLARE_ERROR`). Имя капсом — жёсткая константа: запись в неё
даёт `CONST_ERROR`.

### Коллекции

```kraft
list xs = [1, 2, 3]
xs.add(4)
xs.del(0)
show({xs.join("-")})        # 2-3-4
show({xs.contains(3)})      # TRUE

dict user = {имя: "Kraft", возраст: 25}
show({user[имя]})           # Kraft
user.add("рост", 180)
for k, v in user:
    show({k} = {v})
```

Списки и словари передаются по ссылке. Есть `add`, `del`, `remove`,
`contains`, `count`, `index`, `join`, `take`, `merge`, срезы и запись по
индексу. Полный список — в [builtins.md](docs/builtins.md).

### Модели

Поля создаются в `construct` через `self(...)`, поля в теле модели доступны
только для чтения. Наследования нет.

```kraft
model Counter:
    construct(flint value):
        self(value)
    method inc(flint by) -> flint:
        self.value = self.value + by
        return self.value

Counter c = Counter(5)
show({c.inc(3)})        # 8
```

### Ошибки

У блока ровно три части: `try:`, ветки `trigger <КАТЕГОРИЯ>:`, обязательная
`finally:`.

```kraft
try:
    assert(FALSE, "не сработало")
trigger ASSERT_ERROR, VALUE_ERROR:  # одна ветка на две категории
    show(перехвачено: {error.cat})
trigger ANY_ERROR:
    show(другая: {error.cat})
finally:
    show(всегда)
```

`error` доступен в каждой ветке и только для чтения (`cat`, `msg`, `file`,
`line`, `col`, метод `text()`). `ANY_ERROR` ловит остальное и должен быть
последним и не объединяется с другими категориями. Несколько категорий через
запятую делят одну ветку. `finally` выполняется всегда, даже при `return`.

`panic("CATEGORY"[, "message"])` бросает ошибку с заданной категорией;
сообщение по умолчанию равно категории. Категория — plain-строка из списка
известных категорий. `panic("PANIC_ERROR")` ловится веткой
`trigger PANIC_ERROR` или `trigger ANY_ERROR`.

## Что есть и чего нет

- v0.1 заморожен (`v0.1.0`), `xkraft` собирает себя и на совместимых тестах
  выдаёт побайтово тот же Lua.
- В `xkraft` новая модель включена всегда: только объявления наверху, зоны
  изменений, блоки типов, модели, индексная запись, встроенные и
  `try/trigger/finally`.
- Реализованы `froz`, `panic`, prelude, диапазоны `..`, `in`, группировка
  `trigger CAT1, CAT2:` и установка на Windows.
- Пока не реализованы модули/импорты (`import_file`, `from_file`,
  `import_lib`, `from_lib`), `export`, пространства имён и пакетный менеджер
  `kpm`. Они запланированы на `1.x`.

Параметры типов в `[]` указывать не обязательно — они нужны для конкретных
задач:

```kraft
list nums = [1, 2, 3]               # без параметров — как раньше
list[flint] ints = [1, 2, 3]        # только flint
dict[str|flint] cfg = {возраст: 25} # ключ str, значение flint
froz[flint] frozen = [4, 5, 6]      # только для чтения
```

Запятая в `dict[str, flint]` равнозначна `dict[str|flint]`: слева — тип ключа
(всегда `str`), справа — тип значения. Внутри `[]` допустимы только `str`,
`flint`, `bool`; вложенность и `NONE` запрещены. `froz[T]` — read-only список:
индексы, срезы и `for in` работают, запись и мутирующие методы — нет.

Prelude подключается без `import`: `path_join`, `now_ms`, `parse_args`,
`parse_csv`, `parse_json`, `prelude_cat`. Флаг `--no-prelude` отключает его.

Для Windows: распакуйте `kraft-win.zip`, запустите `install-win.cmd`
(LuaJIT должен быть в `PATH`); команды `xkraft` и `kraft` — одна и та же
программа.

## Для разработчика

Всё служебное лежит в `dev/`, в корне — только готовый `xkraft`.

```text
xkraft          готовый автономный бинарник (то же самое — dist/xkraft)
dist/           минимальная поставка + документация
dev/kraft       замороженный эталон v0.1
dev/xkraft.kraft компилятор на Kraft
dev/src/        рантайм и эталонный компилятор
dev/tests/      тесты
examples/       примеры
docs/           решения, встроенные, шпаргалка
editors/vscode/ подсветка и сниппеты
```

```sh
make check                  # 22 + 18 + 25 + 89 тестов
make dist                   # собрать dist/xkraft и корневой xkraft
(cd dev && ./kraft xkraft.kraft xkraft.kraft > xkraft.lua)   # самокомпиляция
```

## Лицензия

Apache 2.0, см. [LICENSE](LICENSE) и [NOTICE](NOTICE).
Репозиторий: <https://github.com/MIRV314/kraft-lang>
