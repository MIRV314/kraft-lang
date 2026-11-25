#!/bin/sh
# Автоустановка xkraft в одну команду.
#   curl -fsSL https://raw.githubusercontent.com/MIRV314/kraft-lang/main/install-auto.sh | sh
# Либо из клона: sh install-auto.sh
#
# Переменные окружения:
#   KRAFT_SRC    — использовать готовый каталог исходников вместо клона;
#   KRAFT_REPO   — URL репозитория (по умолчанию официальный);
#   KRAFT_TAG    — тег для клона (по умолчанию v0.5.0);
#   KRAFT_PREFIX — префикс установки (по умолчанию /usr/local).
# Ставится xkraft и псевдоним kraft; замороженный v0.1 в систему не ставится.
set -eu

prefix=${KRAFT_PREFIX:-/usr/local}
bin="$prefix/bin"
doc="$prefix/share/doc/kraft"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

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
  tag=${KRAFT_TAG:-v0.5.0}
  echo "install: скачиваем $tag ..."
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$tag" "$repo" "$tmp/src"
  src="$tmp/src"
fi

if [ ! -f "$src/dist/xkraft" ]; then
  echo "install: в $src нет dist/xkraft — соберите дистрибутив: make dist" >&2
  exit 1
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

# Раньше сюда ставилось всё дерево исходников. Теперь нужен только бинарник.
oldlib="$prefix/lib/kraft"
if [ -d "$oldlib" ] && [ -f "$oldlib/src/krt.lua" ]; then
  echo "install: удаляем старое ядро $oldlib ..."
  $sudo rm -rf "$oldlib"
fi

$sudo mkdir -p "$bin" "$doc"
$sudo cp "$src/dist/xkraft" "$bin/xkraft"
$sudo chmod 755 "$bin/xkraft"
# `kraft` — просто имя-псевдоним: запускает тот же x-бинарник,
# а не замороженный эталон v0.1 из dev/.
printf '#!/bin/sh\nexec "%s/xkraft" "$@"\n' "$bin" | $sudo tee "$bin/kraft" >/dev/null
$sudo chmod 755 "$bin/kraft"
for f in README.md LICENSE NOTICE VERSION CHANGELOG.md; do
  if [ -f "$src/dist/$f" ]; then
    $sudo cp "$src/dist/$f" "$doc/$f"
  fi
done

echo "install: проверяем установку ..."
"$bin/xkraft" --version
# Проверяем именно установленный файл: рядом с ним нет исходников и src/.
printf 'show(xkraft ok)\n' > "$tmp/check.kraft"
(cd "$tmp" && "$bin/xkraft" check.kraft) >/dev/null
(cd "$tmp" && "$bin/kraft" check.kraft) >/dev/null

echo "xkraft установлен."
echo "  команды: $bin/xkraft и $bin/kraft (обе запускают xkraft)"
echo "  документация: $doc"
