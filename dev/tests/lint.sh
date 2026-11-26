#!/bin/sh
# Публичный xkraft lint: хороший файл, плохой файл и каталог.
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

mkdir -p "$tmp/dir"
cat > "$tmp/good.kraft" <<'EOF'
flint good_name = 1

func show_good(flint value):
    show({value})
EOF
cp "$tmp/good.kraft" "$tmp/dir/good.kraft"

out=$(./xkraft lint "$tmp/good.kraft" 2>&1)
code=$?
[ "$code" -eq 0 ] && [ "$out" = "ok lint: 1 files checked" ]
check "xkraft-lint-good" $?

printf 'flint BadName = 1\nfunc BadFunc():\n\tshow(clamp(BadName))\n' > "$tmp/bad.kraft"
out=$(./xkraft --lint "$tmp/bad.kraft" 2>&1)
code=$?
[ "$code" -ne 0 ]
check "xkraft-lint-bad-exit" $?
printf '%s\n' "$out" | grep -q 'variable BadName is not snake_case'
check "xkraft-lint-bad-name" $?
printf '%s\n' "$out" | grep -q 'func/method name BadFunc is not snake_case'
check "xkraft-lint-bad-func" $?
printf '%s\n' "$out" | grep -q 'tab in .kraft'
check "xkraft-lint-bad-tab" $?
printf '%s\n' "$out" | grep -q 'removed builtin'
check "xkraft-lint-bad-builtin" $?

mkdir -p "$tmp/clean"
cp "$tmp/good.kraft" "$tmp/clean/a.kraft"
cp "$tmp/good.kraft" "$tmp/clean/b.kraft"
out=$(./xkraft lint "$tmp/clean" 2>&1)
code=$?
[ "$code" -eq 0 ] && [ "$out" = "ok lint: 2 files checked" ]
check "xkraft-lint-dir-clean" $?

cp "$tmp/bad.kraft" "$tmp/dir/bad.kraft"
out=$(./xkraft lint "$tmp/dir" 2>&1)
code=$?
[ "$code" -ne 0 ]
check "xkraft-lint-dir-exit" $?
printf '%s\n' "$out" | grep -q 'bad.kraft'
check "xkraft-lint-dir-bad-file" $?

echo "---"
echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
