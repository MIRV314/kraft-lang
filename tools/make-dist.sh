#!/bin/sh
# Собирает минимальный дистрибутив: один автономный исполняемый файл dist/xkraft.
# Внутрь вшивается рантайм src/krt.lua, поэтому установленному xkraft не нужны
# исходники, папка src/ или revived kraft v0.1.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

command -v luajit >/dev/null 2>&1 || {
  echo "make-dist: нужен LuaJIT (команда luajit в PATH)" >&2
  exit 1
}
[ -x "$root/kraft" ] || {
  echo "make-dist: нет $root/kraft — соберите репозиторий целиком" >&2
  exit 1
}

echo "dist: пересобираем xkraft.lua ..."
"$root/kraft" -c "$root/xkraft.kraft"
mkdir -p "$root/dist"

python3 - "$root" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
lua = (root / "xkraft.lua").read_text()
krt = (root / "src/krt.lua").read_text()

# Дистрибутив не должен зависеть от каталога, в котором его собрали.
lua = re.sub(r'local __KRAFT_SOURCE = "[^"]*"',
             'local __KRAFT_SOURCE = "xkraft.kraft"', lua, count=1)
lua = re.sub(r'krt\.SOURCE_PATH = "[^"]*"',
             'krt.SOURCE_PATH = "xkraft.kraft"', lua, count=1)

old = '''    v_14 = f_1(krt.list({f_95(v_13), "/src/krt.lua"}))
    if krt.truthy((not krt.truthy(krt.file_exists(v_14)))) then
        krt.show_err(("cannot read runtime: " .. krt.tostr(v_14)))
        krt.exit((1))
    end
    v_15 = krt.read_file(v_14)'''
if lua.count(old) != 1:
    sys.exit("make-dist: не нашёл чтение рантайма в xkraft.lua — обновите tools/make-dist.sh")
if "]==]" in krt:
    sys.exit("make-dist: рантайм содержит разделитель ]==]")

anchor = 'local __KRAFT_SOURCE = "xkraft.kraft"\n'
if lua.count(anchor) != 1:
    sys.exit("make-dist: не нашёл объявление __KRAFT_SOURCE")

runtime = "local __KRAFT_DIST_RUNTIME = [==[\n" + krt + "]==]\n\n"
lua = lua.replace(anchor, anchor + runtime, 1)
lua = lua.replace(old, "    v_15 = __KRAFT_DIST_RUNTIME", 1)
if "__KRAFT_EMBEDDED_COMPILER__" in lua:
    sys.exit("make-dist: метка встроенного компилятора уже встречается в Lua")

header = '''#!/bin/sh
# xkraft 0.2.0 — автономный компилятор Kraft.
# lua-код компилятора вшит ниже; внешних файлов и каталога src/ не нужно.
set -eu
tmp=$(mktemp -d "${TMPDIR:-/tmp}/xkraft.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

awk 'seen { print } /^__KRAFT_EMBEDDED_COMPILER__$/ { seen = 1 }' "$0" > "$tmp/compiler.lua"

if [ "${1-}" = "--version" ]; then
  exec luajit "$tmp/compiler.lua" --version
fi

mode=run
flags=""
src=""
while [ $# -gt 0 ]; do
  case $1 in
    --tokens) flags="$flags --tokens"; mode=tokens; shift ;;
    -c) flags="$flags -c"; mode=compile; shift ;;
    --emit-lua) flags="$flags --emit-lua"; mode=emit; shift ;;
    *) src=$1; shift; break ;;
  esac
done

if [ -z "$src" ]; then
  echo "usage: xkraft [--tokens] [-c] file.kraft" >&2
  exit 1
fi

case "$mode" in
  compile)
    luajit "$tmp/compiler.lua" $flags "$src" >/dev/null
    case "$src" in
      *.kraft) chmod +x "${src%.kraft}.lua" 2>/dev/null || true ;;
    esac
    ;;
  tokens|emit)
    exec luajit "$tmp/compiler.lua" $flags "$src"
    ;;
  run)
    luajit "$tmp/compiler.lua" $flags "$src" > "$tmp/program.lua"
    exec luajit "$tmp/program.lua" "$@"
    ;;
esac
exit 0
'''

out = root / "dist" / "xkraft"
out.write_text(header + "__KRAFT_EMBEDDED_COMPILER__\n" + lua)
out.chmod(0o755)
PY

for f in LICENSE NOTICE VERSION CHANGELOG.md; do
  cp "$root/$f" "$root/dist/$f"
done

echo "dist: готово — dist/xkraft ($(wc -c < "$root/dist/xkraft") байт)"
