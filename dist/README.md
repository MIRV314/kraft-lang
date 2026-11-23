# xkraft 0.2.0

`xkraft` — компилятор языка Kraft, написанный на Kraft. Это один автономный
исполняемый файл: внутри уже вшит рантайм, дополнительных каталогов не нужно.
Единственная зависимость — LuaJIT (`luajit` должен быть в `PATH`).

```sh
./xkraft --version
./xkraft program.kraft       # скомпилировать и запустить
./xkraft -c program.kraft    # собрать program.lua рядом
```

Установка одной командой (нужны права `sudo`):

```sh
curl -fsSL https://raw.githubusercontent.com/MIRV314/kraft-lang/main/install-auto.sh | sh
```

Скрипт поставит только команду `xkraft` в `/usr/local/bin`. Ручная установка:
`KRAFT_BIN=~/.local/bin sh install.sh` из корня репозитория.

Полная документация: https://github.com/MIRV314/kraft-lang#readme
Шпаргалка: https://github.com/MIRV314/kraft-lang/blob/main/docs/cheatsheet.md
Лицензия: Apache-2.0, см. `LICENSE` и `NOTICE`.
