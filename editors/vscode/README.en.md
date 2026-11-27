# Kraft for VS Code

> [Russian original: README.md](README.md) — the Russian version is authoritative.

Syntax highlighting and snippets for `.kraft` files: keywords, types, models,
builtins, error categories, `#` comments, strings, and `{...}` interpolation.

## Snippets

Type a prefix and press `Tab`: `func`, `funcv`, `if`, `ifelse`, `for`, `forin`,
`while`, `model`, `try`, `assert`, `show`. `Tab` moves between placeholders.

## Installation

The simplest way is to copy this directory into the extensions folder and
restart VS Code:

```sh
mkdir -p ~/.vscode/extensions
cp -R editors/vscode ~/.vscode/extensions/kraft
```

Or build a `.vsix`:

```sh
cd editors/vscode
npx @vscode/vsce package
code --install-extension kraft-0.2.0.vsix
```

After installation, files with the `.kraft` extension open with the Kraft
language.
