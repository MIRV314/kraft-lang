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
  echo "install: нет $src/dist/xkraft — соберите дистрибутив: make dist" >&2
  exit 1
fi

# Старая ручная установка клала ядро в ~/.kraft; теперь там только документы.
if [ -f "$home/src/krt.lua" ]; then
  echo "install: удаляем старое ядро в $home ..."
  rm -rf "$home/src" "$home/tests" "$home/examples" "$home/docs" \
    "$home/editors" "$home/kraft" "$home/xkraft"
fi

mkdir -p "$bin" "$home"
cp "$src/dist/xkraft" "$bin/xkraft"
chmod 755 "$bin/xkraft"
# `kraft` — псевдоним того же x-бинарника, не эталон v0.1.
cat > "$bin/kraft" <<EOF
#!/bin/sh
exec "$bin/xkraft" "\$@"
EOF
chmod 755 "$bin/kraft"
for f in README.md LICENSE NOTICE VERSION CHANGELOG.md; do
  if [ -f "$src/dist/$f" ]; then
    cp "$src/dist/$f" "$home/$f"
  fi
done

"$bin/xkraft" --version
echo "xkraft установлен."
echo "  команды: $bin/xkraft и $bin/kraft (обе запускают xkraft)"
echo "  документация: $home"
echo "Добавьте $bin в PATH, если его там ещё нет."
