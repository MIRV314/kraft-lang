# Kraft

[![CI](https://github.com/MIRV314/kraft-lang/actions/workflows/ci.yml/badge.svg)](https://github.com/MIRV314/kraft-lang/actions/workflows/ci.yml)
[![release v0.5.0](https://img.shields.io/badge/release-v0.5.0-blue.svg)](https://github.com/MIRV314/kraft-lang/releases/tag/v0.5.0)

[English](README.en.md) · [Релиз v0.5.0](https://github.com/MIRV314/kraft-lang/releases/tag/v0.5.0)

Kraft — небольшой статически типизированный язык: один числовой тип `flint`,
отступы вместо фигурных скобок, интерполяция `{}` вместо склейки строк.
Ошибки показывают категорию, файл, строку и каретку. Ядро растёт библиотеками,
а не новыми ключевыми словами. Компилятор `xkraft` написан на Kraft и собирает
сам себя.

Текущая версия — **0.5.0**.

## Установка

Нужна только LuaJIT (`luajit` в `PATH`).

```sh
curl -fsSL https://raw.githubusercontent.com/MIRV314/kraft-lang/main/install-auto.sh | sh
# или из клона: sh install.sh
xkraft --version                    # xkraft 0.5.0
```

Готовый бинарник лежит в корне репозитория (`./xkraft`) и в
[релизе](https://github.com/MIRV314/kraft-lang/releases/tag/v0.5.0).
Основная команда — `xkraft`. Эталонный компилятор `kraft` v0.1 заморожен,
лежит в `dev/kraft` и в поставку не входит.

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

flint n = input()          # строка извне становится flint
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

Тип при объявлении обязателен, `-> type` указывают для рекурсии и публичного
API. `flint` принимает `input()`, `args()`, `read_text()` и ячейки CSV;
нечисловое значение даёт `TYPE_MISMATCH_ERROR` при запуске, нечисловой литерал —
`TYPE_ERROR` при компиляции. Ошибки перехватываются блоками
`try` / `trigger` / `finally`.

## Зависимости

```sh
kpm init venv
kpm add ./libs/helpers     # или URL: kpm add https://…/pkg.zip
kpm run                    # main.kraft через venv/bin/xkraft
```

Пакеты кладутся в `packages/<name>/`; источник записан в `kraft.json` (`deps`),
точный вариант и хэш — в `kraft.lock`. Для Windows распакуйте `kraft-win.zip`
и запустите `install-win.cmd`.

## Чего пока нет

- LSP и автодополнения: есть только подсветка и сниппеты для VS Code.
- Наследования, полиморфизма, инкапсуляции, свойств и `class`.
- `std/math`, `clamp`, `lerp`, `is_even`.
- Вывода `1.0, 1.5, 2.0` для дробного range: сейчас печатается `1, 1.5, 2`.
- Реестра пакетов: пока только локальные пути и URL.

## Куда дальше

| Хочу… | Открыть |
| --- | --- |
| Кратко повторить синтаксис | [docs/cheatsheet.md](docs/cheatsheet.md) |
| Полный список функций и методов | [docs/builtins.md](docs/builtins.md) |
| Понять, почему так устроено | [docs/decisions.md](docs/decisions.md) |
| Узнать правила компилятора | [docs/rules.md](docs/rules.md) |
| Писать код в стиле проекта | [docs/style.md](docs/style.md) |
| Про философию языка | [docs/philosophy.md](docs/philosophy.md) |
| Посмотреть законченные примеры | [examples/README.md](examples/README.md) |
| Собирать и тестировать | раздел «Для разработчика» ниже |

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

```sh
make check                  # 22 + 20 + 25 + 111 + 11 тестов
make dist                   # собрать dist/xkraft и корневой xkraft
(cd dev && ./kraft xkraft.kraft xkraft.kraft > xkraft.lua)   # самокомпиляция
(cd dev && sh tests/stress.sh)          # вне релиза: стресс и сверка API с docs
(cd dev && sh tests/style.sh)           # вне релиза: базовая проверка стиля
```

## Лицензия

Apache 2.0, см. [LICENSE](LICENSE) и [NOTICE](NOTICE).
Репозиторий: <https://github.com/MIRV314/kraft-lang>
