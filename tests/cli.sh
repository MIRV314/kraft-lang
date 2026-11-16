#!/bin/sh
# CLI v0.1: -c (сборка .lua), --emit-lua, аргументы, stdin.
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

# 1. -c собирает исполняемый .lua рядом с исходником.
cp examples/hello.kraft "$tmp/hello.kraft"
./kraft -c "$tmp/hello.kraft"
direct=$(./kraft "$tmp/hello.kraft")
compiled=$("$tmp/hello.lua")
[ -x "$tmp/hello.lua" ] && [ "$direct" = "$compiled" ]
check "compile-run" $?

# 2. --emit-lua печатает самодостаточный Lua с шебангом.
./kraft --emit-lua "$tmp/hello.kraft" > "$tmp/emitted.lua"
emitted=$(luajit "$tmp/emitted.lua")
head -1 "$tmp/emitted.lua" | grep -q '^#!/usr/bin/env luajit$' && [ "$direct" = "$emitted" ]
check "emit-lua" $?

# 3. args()[0] — исходник, дальше аргументы; совпадает у run и -c.
cat > "$tmp/args.kraft" <<'EOF'
for x in args():
    show({x})
EOF
direct=$(./kraft "$tmp/args.kraft" один два)
./kraft -c "$tmp/args.kraft"
compiled=$("$tmp/args.lua" один два)
[ "$direct" = "$compiled" ]
check "args" $?

# 4. # stdin: работает и в -c.
cat > "$tmp/read.kraft" <<'EOF'
# stdin: строка
show({input(> )})
EOF
direct=$(./kraft "$tmp/read.kraft")
./kraft -c "$tmp/read.kraft"
compiled=$("$tmp/read.lua")
[ "$direct" = "$compiled" ]
check "stdin-compiled" $?

# 5. Собранный .lua работает без исходника, включая каретку рантайм-ошибки.
cat > "$tmp/self.kraft" <<'EOF'
list xs = [1, "два"]
flint n = xs[1] + 1
EOF
./kraft -c "$tmp/self.kraft"
cp "$tmp/self.lua" "$tmp/self_only.lua"
rm -f "$tmp/self.kraft" "$tmp/self.lua"
out=$("$tmp/self_only.lua" 2>&1)
code=$?
printf '%s\n' "$out" | grep -q "self.kraft:2" && \
  printf '%s\n' "$out" | grep -q '^ *2 | flint n = xs\[1\] + 1$' && \
  [ "$code" -eq 1 ]
check "self-contained" $?

# 6. Без файла — usage и код 1.
./kraft > /dev/null 2>&1
[ $? -eq 1 ]
check "usage" $?

echo "---"
echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
