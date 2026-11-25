#!/bin/sh
# Стресс-тесты: НЕ входят в make check и не попадают в dist.
# Запуск вручную: dev/tests/stress.sh
# Каждый случай — tests/stress/<name>.kraft, <name>.out, опционально
# <name>.stdin, <name>.argv (по строке на аргумент) и <name>.code (код выхода).
set -u
cd "$(dirname "$0")/.." || exit 1

fail=0
total=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

check() {
  total=$((total + 1))
  if [ "$2" -eq 0 ]; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    fail=$((fail + 1))
  fi
}

# Сверка «что есть в компиляторе» с документацией: ловит забытые функции.
python3 - <<'PY' > "$tmp/audit.out" 2>&1
import pathlib, re
root = pathlib.Path('.')
src = (root / 'xkraft.kraft').read_text()
docs = ''.join(p.read_text() for p in (root / '../docs').glob('*.md'))
docs += (root / '../README.md').read_text()
docs += (root / '../README.en.md').read_text()

def names_between(a, b, pattern=r'if name == "([a-zA-Z_]+)"'):
    start = src.index(a)
    end = src.index(b, start) if b else len(src)
    return sorted(set(re.findall(pattern, src[start:end])))

groups = [
    ('builtins', names_between('func builtin_info', 'func is_builtin')),
    ('methods', names_between('func method_info', 'func is_reserved')),
    ('keywords', names_between('func is_keyword', 'func is_template_func', r'w == "([a-zA-Z_]+)"')),
]
for label, names in groups:
    missing = [n for n in names if n not in docs]
    if missing:
        print('undocumented %s: %s' % (label, ' '.join(missing)))
PY
audit=$?
# python3 не может легко проверить свой stdout через pipe, поэтому просто смотрим файл.
if [ -s "$tmp/audit.out" ]; then
  cat "$tmp/audit.out"
  check docs-audit 1
else
  check docs-audit 0
fi

# Самокомпиляция: эталон и самособранный компилятор обязаны дать тот же Lua.
./kraft xkraft.kraft xkraft.kraft > "$tmp/direct.lua" 2> "$tmp/self.err"
luajit xkraft.lua xkraft.kraft > "$tmp/self.lua" 2>> "$tmp/self.err"
if [ -s "$tmp/self.err" ]; then
  sed 's/^/     /' "$tmp/self.err"
  check self-host 1
elif cmp -s "$tmp/direct.lua" "$tmp/self.lua"; then
  check self-host 0
else
  echo "     byte-identical Lua mismatch"
  check self-host 1
fi

compiler=../xkraft
for f in tests/stress/*.kraft; do
  [ -e "$f" ] || continue
  name=$(basename "$f" .kraft)
  expected="tests/stress/$name.out"
  code=0
  [ -f "tests/stress/$name.code" ] && code=$(cat "tests/stress/$name.code")

  ok=1
  "$compiler" --emit-lua "$f" > "$tmp/$name.lua" 2> "$tmp/$name.err"
  cc=$?
  if [ -s "$tmp/$name.err" ]; then
    cat "$tmp/$name.err" > "$tmp/$name.out"
  elif [ "$cc" -eq 0 ]; then
    set --
    if [ -f "tests/stress/$name.argv" ]; then
      while IFS= read -r arg || [ -n "$arg" ]; do set -- "$@" "$arg"; done < "tests/stress/$name.argv"
    fi
    if [ -f "tests/stress/$name.stdin" ]; then
      luajit "$tmp/$name.lua" "$@" < "tests/stress/$name.stdin" > "$tmp/$name.out" 2>&1
    else
      luajit "$tmp/$name.lua" "$@" < /dev/null > "$tmp/$name.out" 2>&1
    fi
  else
    cat "$tmp/$name.err" > "$tmp/$name.out"
  fi
  got=$?
  if [ "$cc" -ne 0 ] && [ "$code" -ne 0 ]; then got=$code; fi
  if [ "$got" -ne "$code" ]; then
    echo "     $name: exit $got, expected $code"
    ok=0
  fi
  if ! diff -u "$expected" "$tmp/$name.out" > "$tmp/$name.diff" 2>&1; then
    echo "     $name: output differs"
    sed 's/^/     /' "$tmp/$name.diff"
    ok=0
  fi
  check "$name" $((1 - ok))
done

echo "---"
echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
