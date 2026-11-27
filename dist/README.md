# Kraft

[![CI](https://github.com/MIRV314/kraft-lang/actions/workflows/ci.yml/badge.svg)](https://github.com/MIRV314/kraft-lang/actions/workflows/ci.yml)
[![release v0.9.1](https://img.shields.io/badge/release-v0.9.1-blue.svg)](https://github.com/MIRV314/kraft-lang/releases)

[English](README.en.md) · [Релизы](https://github.com/MIRV314/kraft-lang/releases)

Kraft — небольшой статически типизированный язык: один числовой тип `flint`,
отступы вместо фигурных скобок, интерполяция `{}` вместо склейки строк.
Ошибки показывают категорию, файл, строку и каретку. Ядро растёт библиотеками,
а не новыми ключевыми словами. Компилятор `xkraft` написан на Kraft и собирает
сам себя.

Текущая версия — **0.9.1**.

## Установка

Нужна только LuaJIT (`luajit` в `PATH`).

```sh
curl -fsSL https://raw.githubusercontent.com/MIRV314/kraft-lang/main/install-auto.sh | sh
# или из клона: sh install.sh
kraft --version                     # xkraft 0.9.1; kraft — псевдоним
kraft --update                      # обновить бинарник и kpm из GitHub Releases
xkraft lint [path...]               # базовые правила стиля
kpm --version                       # kpm 1.0.0
```

Готовый бинарник лежит в корне репозитория (`./xkraft`) и в
[релизах](https://github.com/MIRV314/kraft-lang/releases).
Основная команда — `kraft`, тот же бинарник доступен как `xkraft`. Замороженный
`kraft` v0.1 лежит в `dev/kraft` и в поставку не входит.

`kraft --update` (`xkraft --update`) скачивает последний релиз, сверяет оба
хэша с `SHA256SUMS` и только после успешной проверки меняет и бинарник, и `kpm`.
Замена идёт через копию рядом с целью — работает и на другой файловой системе.
На Windows обновляются файлы из `kraft-win.zip`. Обычная проверка новой версии
происходит раз в сутки только в терминале; отключить её можно через
`KRAFT_NO_UPDATE_CHECK=1`. `kpm update` убран: `kpm` больше не обновляется сам.

Оба POSIX-установщика ставят `xkraft`, `kpm` и псевдоним `kraft`. В AUR-пакете
псевдоним `kraft` не создаётся. `kpm --version` показывает `1.0.0`.

## Первая программа

```kraft
str name = "Kraft"
show(привет, {name}!)
show({2 + 2})
```

```sh
xkraft hello.kraft
```

```text
привет, Kraft!
4
```

Компиляция и запуск — одна команда. `xkraft -c hello.kraft` оставит рядом
`hello.lua`, `xkraft --tokens hello.kraft` покажет токены.

## Основы за пять минут

```kraft
from_lib "std/fos" import read_text

flint total = 2
str word = "два"
show({word}: {total})      # два: 2

flint n = input()          # строка извне сразу приводится к flint
show({n + 1})

func twice(flint x) -> flint:
    return x * 2

for i 1..3:                # 1, 2; правая граница не входит
    total += i
show({twice(total)})       # 10

model Counter:
    construct(flint value):
        self(value)
    method inc(flint by) -> flint:
        self.value = self.value + by
        return self.value

Counter c = Counter(5)
show({c.inc(3)})           # 8

show({read_text("data.txt")})
```

Тип при объявлении обязателен; тип каждого аргумента функции тоже обязателен.
`-> type` указывают для рекурсии и публичного API. `flint` принимает `input()`,
`args()`, `read_text()` и ячейки CSV без явного `flint(...)`: числовой строковый
литерал (`flint n = "42"`) проверяется при компиляции, нечисловой (`flint n = "x"`)
даёт `TYPE_ERROR`; нечисловое значение извне даёт `TYPE_MISMATCH_ERROR` при
запуске. Ошибки перехватываются блоками `try` / `trigger` / `finally`.

В срезах `..` разделяет границы, `...` задаёт шаг: `xs[..2]` — до индекса 2 не
включительно, `xs[2..]` — до конца, `xs[...2]` — весь список с шагом 2,
`xs[2...3]` — от 2 до конца с шагом 3, `xs[...]` — копия всего. Пустая ветка или
тело цикла пишется через `pass`.

## Зависимости

```sh
kpm init venv
kpm add ./libs/helpers     # или URL: kpm add https://…/pkg.zip
kpm run                    # main.kraft через venv/bin/xkraft
```

`kpm add ./libs/helpers` добавляет локальный пакет в `deps` файла `kraft.json`,
копирует его в `packages/helpers` и записывает точный вариант и хэш в
`kraft.lock`. Вместо пути можно указать URL. Пакеты кладутся в
`packages/<name>/`. Для Windows распакуйте `kraft-win.zip` и запустите
`install-win.cmd`.

## Чего пока нет

- LSP и автодополнения: есть только подсветка и сниппеты для VS Code.
- Наследования, полиморфизма и инкапсуляции как языковой ООП: паттерны живут в
  std. `class` не вводится — его роль выполняет `model`; свойства остаются
  отдельным будущим решением.
- `sin`, `cos`, `tan` и `log` в `std/math`: пока есть только `pow` и `random`.
- `clamp`, `lerp` и `is_even` не вводятся.
- Реестра пакетов: пока только локальные пути и URL.
- `std/http`, декораторов и `async`/авто-await: запланированы после `1.0`.

## Куда дальше

| Хочу… | Открыть |
| --- | --- |
| Кратко повторить синтаксис | [docs/cheatsheet.md](docs/cheatsheet.md) |
| Полный список функций и методов | [docs/builtins.md](docs/builtins.md) |
| Разобраться с библиотеками | [docs/libs.md](docs/libs.md) |
| Понять, почему так устроено | [docs/decisions.md](docs/decisions.md) |
| Узнать правила компилятора | [docs/rules.md](docs/rules.md) |
| Писать код в стиле проекта | [docs/style.md](docs/style.md) |
| Про философию языка | [docs/philosophy.md](docs/philosophy.md) |
| Посмотреть законченные примеры | [examples/README.md](examples/README.md) |
| Собирать и тестировать | раздел «Для разработчика» ниже |

План релизов: `0.8` — публичный `xkraft lint` и вывод `1.0, 1.5, 2.0` для
дробного range; `0.9` — `PI` в ядре, hotfix `kpm` и свежая документация.
Следующий стабильный `1.0` не включает сайт, реестр, AUR и витрину примеров:
они отложены на отдельный релиз. Затем `std/http` (`1.1`), декораторы (`1.2`),
`async` с авто-await (`1.3`) и затем LSP — не только для VS Code.

## Для разработчика

Всё служебное лежит в `dev/`, в корне — только готовый `xkraft`.

```text
xkraft            готовый автономный бинарник (то же, что dist/xkraft)
dist/             минимальная поставка + документация
dev/xkraft.kraft  компилятор на Kraft
dev/kraft         замороженный эталон v0.1, нужен только для самокомпиляции
dev/src/          рантайм и эталонный компилятор
dev/stdlib/       встроенные модули std/fos и std/cli
dev/kpm.lua       менеджер пакетов
dev/tests/        тесты
examples/         примеры
docs/             документация
editors/vscode/   подсветка и сниппеты
```

Замороженный `kraft` v0.1 не знает нового синтаксиса (`pass`, новые срезы):
он нужен только для самокомпиляции. Новый код принимает `xkraft` и псевдоним
`kraft` из поставки.

```sh
make check                  # 22 + 20 + 25 + 115 + 13 + 6 + 9 тестов
make dist                   # собрать dist/xkraft и корневой xkraft
(cd dev && ./kraft xkraft.kraft xkraft.kraft > xkraft.lua)   # самокомпиляция
(cd dev && sh tests/stress.sh)          # вне релиза: стресс и сверка API с docs
(cd dev && sh tests/style.sh)           # вне релиза: базовая проверка стиля
```

## Лицензия

Apache 2.0, см. [LICENSE](LICENSE) и [NOTICE](NOTICE).
Репозиторий: <https://github.com/MIRV314/kraft-lang>
