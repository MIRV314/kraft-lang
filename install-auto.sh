#!/bin/sh
# Автоустановка Kraft в одну команду.
#   curl -fsSL https://raw.githubusercontent.com/MIRV314/kraft-lang/main/install-auto.sh | sh
# Либо из клона: sh install-auto.sh
#
# Переменные окружения:
#   KRAFT_SRC   — использовать готовый каталог исходников вместо клона;
#   KRAFT_REPO  — URL репозитория (по умолчанию официальный);
#   KRAFT_TAG   — тег для клона (по умолчанию v0.2.0);
#   KRAFT_PREFIX — префикс установки (по умолчанию /usr/local).
set -eu

prefix=${KRAFT_PREFIX:-/usr/local}
lib="$prefix/lib/kraft"
bin="$prefix/bin"

if ! command -v luajit >/dev/null 2>&1; then
  echo "install: нужен LuaJIT (команда luajit должна быть в PATH)" >&2
  exit 1
fi

if [ -n "${KRAFT_SRC:-}" ]; then
  src=$(CDPATH= cd -- "$KRAFT_SRC" && pwd)
else
  if ! command -v git >/dev/null 2>&1; then
    echo "install: нужен git, чтобы скачать исходники" >&2
    exit 1
  fi
  repo=${KRAFT_REPO:-https://github.com/MIRV314/kraft-lang.git}
  tag=${KRAFT_TAG:-v0.2.0}
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  echo "install: скачиваем $tag ..."
  git clone --quiet --depth 1 --branch "$tag" "$repo" "$tmp/src"
  src="$tmp/src"
fi

if [ "$(id -u)" -eq 0 ]; then
  sudo=""
elif [ "$prefix" != "/usr/local" ] && [ -w "$(dirname "$prefix")" ]; then
  sudo=""
elif command -v sudo >/dev/null 2>&1; then
  echo "install: для $prefix нужны права администратора (sudo)"
  sudo="sudo"
else
  echo "install: нет прав на $prefix и не найден sudo" >&2
  exit 1
fi

$sudo mkdir -p "$lib" "$bin"
tar -C "$src" -cf - --exclude=./.git --exclude=./xkraft.lua . |
  $sudo tar -C "$lib" -xf -

printf '#!/bin/sh\nexec "%s/kraft" "$@"\n' "$lib" | $sudo tee "$bin/kraft" >/dev/null
printf '#!/bin/sh\nexec "%s/xkraft" "$@"\n' "$lib" | $sudo tee "$bin/xkraft" >/dev/null
$sudo chmod +x "$bin/kraft" "$bin/xkraft"

echo "install: проверяем установку ..."
"$bin/kraft" --version
"$bin/xkraft" --version
(cd "$lib" && ./xkraft examples/features.kraft >/dev/null)
echo "Kraft установлен."
echo "  ядро:    $lib"
echo "  обёртки: $bin"
