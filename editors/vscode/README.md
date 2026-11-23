# Kraft for VS Code

Подсветка синтаксиса для файлов `.kraft`: ключевые слова, типы, модели,
категории ошибок, комментарии `#`, строки и интерполяция `{...}`.

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
