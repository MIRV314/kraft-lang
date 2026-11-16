#!/bin/sh
# xkraft: компилятор на Kraft. Проверяем два уровня.
#   1. xkraft компилирует все cases так же, как эталонный ./kraft.
#   2. xkraft компилирует сам себя, и собранный им компилятор даёт тот же Lua.
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

# Компилирует и запускает case.
#   $1 — компилятор: direct | self
#   $2 — файл case
#   $3 — префикс выходных файлов: <prefix>.lua и <prefix>.out
# Возвращает код программы (или код ошибки компиляции).
compile_case() {
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

for f in tests/cases/*.kraft; do
  [ -e "$f" ] || continue
  name=$(basename "$f" .kraft)
  expected="tests/cases/$name.out"
  expected_code=0
  if [ -f "tests/cases/$name.code" ]; then
    expected_code=$(cat "tests/cases/$name.code")
  fi

  ok=1

  # Эталонный xkraft.
  compile_case direct "$f" "$tmp/$name.direct"
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

  # xkraft, собранный собой.
  compile_case self "$f" "$tmp/$name.self"
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

  # Оба компилятора должны выдать байт-в-байт одинаковый Lua.
  if [ "$expected_code" -eq 0 ]; then
    if ! diff -q "$tmp/$name.direct.lua" "$tmp/$name.self.lua" > /dev/null 2>&1; then
      echo "     direct and self produced different Lua"
      ok=0
    fi
  fi

  check "$name" $((1 - ok))
done

# -c: xkraft пишет .lua рядом с исходником, файл исполняется без исходника.
cp tests/cases/hello.kraft "$tmp/hello.kraft"
./kraft xkraft.kraft -c "$tmp/hello.kraft" > /dev/null 2>&1
code=$?
if [ "$code" -eq 0 ] && [ -f "$tmp/hello.lua" ]; then
  luajit "$tmp/hello.lua" > "$tmp/hello.got" 2>&1
  code=$?
  diff -q tests/cases/hello.out "$tmp/hello.got" > /dev/null 2>&1
  check "compile-c" $?
else
  check "compile-c" 1
fi

# --tokens: лексер xkraft печатает токены с позициями.
./kraft xkraft.kraft --tokens tests/cases/hello.kraft > "$tmp/tokens.x" 2>&1
code=$?
first=$(head -1 "$tmp/tokens.x")
last=$(tail -1 "$tmp/tokens.x")
[ "$code" -eq 0 ] && [ "$first" = "kw 1:1 str" ] && \
  printf '%s\n' "$last" | grep -q '^eof '
check "tokens" $?

echo "---"
echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
