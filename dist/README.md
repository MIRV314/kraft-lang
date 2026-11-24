# xkraft 0.3.0

`xkraft` — компилятор языка Kraft, написанный на Kraft. Это один автономный
исполняемый файл: внутри уже вшит рантайм, дополнительных каталогов не нужно.
Единственная зависимость — LuaJIT (`luajit` должен быть в `PATH`).

```sh
./xkraft --version
./xkraft program.kraft       # скомпилировать и запустить
./xkraft -c program.kraft    # собрать program.lua рядом
```

Prelude (`path_join`, `now_ms`, `parse_args`, `parse_csv`, `parse_json`,
`prelude_cat`) доступен без `import`; `--no-prelude` отключает его.
Для Windows — `kraft-win.zip`: распаковать и запустить `install-win.cmd`
(LuaJIT уже должен быть в `PATH`).

Установка одной командой (нужны права `sudo`):

```sh
curl -fsSL https://raw.githubusercontent.com/MIRV314/kraft-lang/main/install-auto.sh | sh
```

Скрипт поставит `xkraft` и псевдоним `kraft` в `/usr/local/bin` — оба запускают
один и тот же x-бинарник. На Windows те же два имени дают `xkraft.cmd` и
`kraft.cmd`. Ручная установка: `sh install.sh` из корня репозитория.

Полная документация: https://github.com/MIRV314/kraft-lang#readme
Шпаргалка: https://github.com/MIRV314/kraft-lang/blob/main/docs/cheatsheet.md
Лицензия: Apache-2.0, см. `LICENSE` и `NOTICE`.
