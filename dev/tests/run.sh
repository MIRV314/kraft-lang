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
  expected_code=0
  if [ -f "tests/cases/$name.code" ]; then
    expected_code=$(cat "tests/cases/$name.code")
  fi
  out=$(mktemp)

  ./kraft "$f" > "$out" 2>&1
  actual_code=$?

  if [ "$actual_code" -ne "$expected_code" ]; then
    echo "FAIL $name (exit $actual_code, expected $expected_code)"
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
