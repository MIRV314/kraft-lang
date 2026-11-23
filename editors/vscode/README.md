# Kraft for VS Code

Подсветка синтаксиса и сниппеты для файлов `.kraft`: ключевые слова, типы,
модели, встроенные функции, категории ошибок, комментарии `#`, строки и
интерполяция `{...}`.

## Сниппеты

Набери префикс и нажми `Tab`: `func`, `funcv`, `if`, `ifelse`, `for`, `forin`,
`while`, `model`, `try`, `assert`, `show`. Переходы между полями — `Tab`.

## Установка

Самый простой способ — скопировать этот каталог в папку расширений и
перезапустить VS Code:

```sh
mkdir -p ~/.vscode/extensions
cp -R editors/vscode ~/.vscode/extensions/kraft
```

Либо собрать `.vsix`:

```sh
cd editors/vscode
npx @vscode/vsce package
code --install-extension kraft-0.2.0.vsix
```

После установки файлы с расширением `.kraft` открываются с языком Kraft.
