#!/bin/sh
# Новые возможности ядра: случаи в tests/new компилируются xkraft.
# Проверяем прямой xkraft, собранный собой xkraft, вывод и код возврата,
# а для успешной компиляции — побайтовое совпадение Lua.
set -u
cd "$(dirname "$0")/.." || exit 1

fail=0
total=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

check() {
  name=$1
  total=$((total + 1))
  if [ "$2" -eq 0 ]; then
    echo "ok   $name"
  else
    echo "FAIL $name"
    fail=$((fail + 1))
  fi
}

# Собираем xkraft им же самим: эталонный kraft -> Lua.
if ./kraft xkraft.kraft xkraft.kraft > "$tmp/xkraft_self.lua" 2> "$tmp/self.err"; then
  check "self-compile" 0
else
  check "self-compile" 1
  sed 's/^/     /' "$tmp/self.err"
fi

# Компилирует и запускает случай.
#   $1 — компилятор: direct | self
#   $2 — файл
#   $3 — префикс выходных файлов
# Возвращает код компиляции или код программы.
run_case() {
  comp=$1
  src=$2
  prefix=$3
  if [ "$comp" = "direct" ]; then
    ./kraft xkraft.kraft "$src" > "$prefix.lua" 2> "$prefix.err"
  else
    luajit "$tmp/xkraft_self.lua" "$src" > "$prefix.lua" 2> "$prefix.err"
  fi
  code=$?
  if [ "$code" -ne 0 ]; then
    cat "$prefix.err" > "$prefix.out"
    return "$code"
  fi
  luajit "$prefix.lua" > "$prefix.out" 2>&1
  return $?
}

for f in tests/new/*.kraft; do
  [ -e "$f" ] || continue
  name=$(basename "$f" .kraft)
  expected="tests/new/$name.out"
  expected_code=0
  if [ -f "tests/new/$name.code" ]; then
    expected_code=$(cat "tests/new/$name.code")
  fi

  ok=1

  run_case direct "$f" "$tmp/$name.direct"
  got_code=$?
  if [ "$got_code" -ne "$expected_code" ]; then
    echo "     direct: exit $got_code, expected $expected_code"
    ok=0
  fi
  if ! diff -u "$expected" "$tmp/$name.direct.out" > "$tmp/$name.direct.diff" 2>&1; then
    echo "     direct: output differs"
    sed 's/^/     /' "$tmp/$name.direct.diff"
    ok=0
  fi

  run_case self "$f" "$tmp/$name.self"
  got_code=$?
  if [ "$got_code" -ne "$expected_code" ]; then
    echo "     self: exit $got_code, expected $expected_code"
    ok=0
  fi
  if ! diff -u "$expected" "$tmp/$name.self.out" > "$tmp/$name.self.diff" 2>&1; then
    echo "     self: output differs"
    sed 's/^/     /' "$tmp/$name.self.diff"
    ok=0
  fi

  if [ -s "$tmp/$name.direct.lua" ] && [ -s "$tmp/$name.self.lua" ]; then
    if ! diff -q "$tmp/$name.direct.lua" "$tmp/$name.self.lua" > /dev/null 2>&1; then
      echo "     direct and self produced different Lua"
      ok=0
    fi
  fi

  check "$name" $((1 - ok))
done

echo "---"
echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
