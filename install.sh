#!/bin/sh
# Установка xkraft: один автономный файл в KRAFT_BIN, документы в KRAFT_HOME.
#   sh install.sh
#   KRAFT_HOME=~/.local/share/kraft KRAFT_BIN=~/.local/bin sh install.sh
set -eu

src=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
home=${KRAFT_HOME:-$HOME/.kraft}
bin=${KRAFT_BIN:-$HOME/.local/bin}

if ! command -v luajit >/dev/null 2>&1; then
  echo "install: нужен LuaJIT (команда luajit должна быть в PATH)" >&2
  exit 1
fi
if [ ! -f "$src/dist/xkraft" ]; then
  echo "install: нет $src/dist/xkraft — соберите дистрибутив: ./tools/make-dist.sh" >&2
  exit 1
fi

mkdir -p "$bin" "$home"
cp "$src/dist/xkraft" "$bin/xkraft"
chmod 755 "$bin/xkraft"
for f in README.md LICENSE NOTICE VERSION CHANGELOG.md; do
  if [ -f "$src/dist/$f" ]; then
    cp "$src/dist/$f" "$home/$f"
  fi
done

"$bin/xkraft" --version
echo "xkraft установлен."
echo "  команда: $bin/xkraft"
echo "  документация: $home"
echo "Добавьте $bin в PATH, если его там ещё нет."
