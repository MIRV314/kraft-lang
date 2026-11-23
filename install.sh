#!/bin/sh
# Установка Kraft: копирует ядро в KRAFT_HOME и ставит обёртки в KRAFT_BIN.
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

mkdir -p "$home" "$bin"

if [ "$src" != "$home" ]; then
  tar -C "$src" -cf - --exclude=./.git --exclude=./xkraft.lua . |
    tar -C "$home" -xf -
fi

cat > "$bin/kraft" <<EOF
#!/bin/sh
exec "$home/kraft" "\$@"
EOF
cat > "$bin/xkraft" <<EOF
#!/bin/sh
exec "$home/xkraft" "\$@"
EOF
chmod +x "$bin/kraft" "$bin/xkraft"

echo "Kraft установлен."
echo "  ядро:    $home"
echo "  обёртки: $bin"
echo "Добавьте $bin в PATH, если его там ещё нет."
