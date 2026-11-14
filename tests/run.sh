#!/bin/sh
# Тесты v0.1: вывод программы сравнивается с эталоном.
# Запуск: ./tests/run.sh  или  make check
set -u
cd "$(dirname "$0")/.." || exit 1

fail=0
total=0

for f in tests/cases/*.kraft; do
  [ -e "$f" ] || continue
  total=$((total + 1))
  name=$(basename "$f" .kraft)
  expected="tests/cases/$name.out"
  out=$(mktemp)

  if ! ./kraft "$f" > "$out" 2>&1; then
    echo "FAIL $name (exit code)"
    sed 's/^/     /' "$out"
    fail=$((fail + 1))
  elif ! diff -u "$expected" "$out" > /dev/null 2>&1; then
    echo "FAIL $name"
    diff -u "$expected" "$out" | sed 's/^/     /'
    fail=$((fail + 1))
  else
    echo "ok   $name"
  fi

  rm -f "$out"
done

echo "---"
echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
