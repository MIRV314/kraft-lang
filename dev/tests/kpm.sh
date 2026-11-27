#!/bin/sh
# kpm: venv, manifest, локальные пакеты и запуск.
set -u
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
repo=$(CDPATH= cd -- "$root/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail=0
total=0
check() {
  total=$((total + 1))
  if [ "$2" -eq 0 ]; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    fail=$((fail + 1))
  fi
}

kpm() {
  XKRAFT="$repo/xkraft" luajit "$root/kpm.lua" "$@"
}

mkdir -p "$tmp/proj" "$tmp/pkgsrc/hello"
printf 'show(privet)\n' > "$tmp/proj/main.kraft"
printf 'show(hello package)\n' > "$tmp/pkgsrc/hello/main.kraft"

cd "$tmp/proj" || exit 1
out=$(kpm --version 2>&1)
[ "$out" = "kpm 1.0.0" ] && check version 0 || check version 1
kpm init venv demo >/dev/null && check init 0 || check init 1
[ -f kraft.json ] && [ -f kraft.lock ] && [ -x venv/bin/xkraft ] && [ -d packages ] \
  && check venv 0 || check venv 1
grep -q '"deps": {}' kraft.json && check manifest 0 || check manifest 1
kpm add "$tmp/pkgsrc/hello" >/dev/null 2>&1 && check add 0 || check add 1
[ -f packages/hello/main.kraft ] && check installed 0 || check installed 1
kpm list 2>/dev/null | grep -q '^hello ' && check list 0 || check list 1
out=$(kpm run 2>/dev/null) && [ "$out" = "privet" ] && check run 0 || check run 1
kpm del hello >/dev/null 2>&1 && check del 0 || check del 1
[ ! -e packages/hello ] && check removed 0 || check removed 1
grep -q '"deps": {}' kraft.json && check manifest_clean 0 || check manifest_clean 1

# Обновление — только через kraft --update; kpm больше не обновляет.
out=$(kpm update 2>&1)
code=$?
[ "$code" -ne 0 ] && [ "$out" = "kpm: обновление через kpm отключено — используйте kraft --update" ] \
  && check update_disabled 0 || check update_disabled 1
out=$(kpm --update 2>&1)
code=$?
[ "$code" -ne 0 ] && [ "$out" = "kpm: обновление через kpm отключено — используйте kraft --update" ] \
  && check dash_update_disabled 0 || check dash_update_disabled 1

echo "---"
echo "$total/$total kpm checks (fail=$fail)"
[ "$fail" -eq 0 ]
