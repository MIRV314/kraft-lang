# Kraft

[![CI](https://github.com/MIRV314/kraft-lang/actions/workflows/ci.yml/badge.svg)](https://github.com/MIRV314/kraft-lang/actions/workflows/ci.yml)
[![release v0.2.0](https://img.shields.io/badge/release-v0.2.0-blue.svg)](https://github.com/MIRV314/kraft-lang/releases/tag/v0.2.0)

[English](README.en.md) · [Шпаргалка](docs/cheatsheet.md) · [Встроенные](docs/builtins.md) · [Release](https://github.com/MIRV314/kraft-lang/releases/tag/v0.2.0)

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
xkraft --version                    # xkraft 0.2.0
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
| модель | `Counter(5)` |

`NONE` — пустое значение; ложны только `FALSE` и `NONE` (`0`, `""`, `[]` —
истинны). `show` печатает шаблон: всё вне `{}` — текст, внутри — выражение.

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
trigger ASSERT_ERROR:
    show(перехвачено: {error.msg})
trigger ANY_ERROR:
    show(другая: {error.cat})
finally:
    show(всегда)
```

`error` доступен в каждой ветке и только для чтения (`cat`, `msg`, `file`,
`line`, `col`, метод `text()`). `ANY_ERROR` ловит остальное и должен быть
последним. `finally` выполняется всегда, даже при `return`.

## Что есть и чего нет

- v0.1 заморожен (`v0.1.0`), `xkraft` собирает себя и на совместимых тестах
  выдаёт побайтово тот же Lua.
- В `xkraft` новая модель включена всегда: только объявления наверху, зоны
  изменений, блоки типов, модели, индексная запись, встроенные и
  `try/trigger/finally`.
- Пока не реализовано: `froz`, `panic`, prelude, модули/импорты и установка
  на Windows.

Типизированные коллекции тоже пока не работают, но синтаксис уже зафиксирован:

```kraft
list[flint] nums = [1, 2, 3]
dict[str|flint] cfg = {возраст: 25}
froz[flint] frozen = [4, 5, 6]   # неизменяемый список с типом элемента
```

`froz[T]` — коллекция с доступом только на чтение, по тому же принципу, что
`list[T]`. Реализация запланирована вместе с prelude.

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
make check                  # 22 + 16 + 25 + 71 тест
make dist                   # собрать dist/xkraft и корневой xkraft
(cd dev && ./kraft xkraft.kraft xkraft.kraft > xkraft.lua)   # самокомпиляция
```

## Лицензия

Apache 2.0, см. [LICENSE](LICENSE) и [NOTICE](NOTICE).
Репозиторий: <https://github.com/MIRV314/kraft-lang>
