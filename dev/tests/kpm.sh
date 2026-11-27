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

# `kpm update`: фейковый релиз, замена и kpm, и xkraft.
mkdir -p "$tmp/bin" "$tmp/fake"
printf '#!/bin/sh\n# new kpm\n' > "$tmp/fake/kpm"
printf '#!/bin/sh\n# new xkraft\n' > "$tmp/fake/xkraft"
(cd "$tmp/fake" && sha256sum kpm xkraft > SHA256SUMS)
cp "$repo/kpm" "$tmp/bin/kpm"
cp "$repo/xkraft" "$tmp/bin/xkraft"
out=$(KRAFT_NO_UPDATE_CHECK=1 KPM_UPDATE_DOWNLOAD="$tmp/fake" "$tmp/bin/kpm" update 2>&1)
code=$?
[ "$code" -eq 0 ] && [ "$out" = "kpm: обновлены kpm и xkraft" ] && \
  cmp -s "$tmp/fake/kpm" "$tmp/bin/kpm" && \
  cmp -s "$tmp/fake/xkraft" "$tmp/bin/xkraft" && check update 0 || check update 1

# Подмена хэша: оба файла остаются прежними.
cp "$repo/kpm" "$tmp/bin/kpm"
cp "$repo/xkraft" "$tmp/bin/xkraft"
printf '%s  kpm\n' "$(printf '%064d' 0)" > "$tmp/fake/SHA256SUMS"
sha256sum "$tmp/fake/xkraft" | sed 's|  .*|  xkraft|' >> "$tmp/fake/SHA256SUMS"
out=$(KRAFT_NO_UPDATE_CHECK=1 KPM_UPDATE_DOWNLOAD="$tmp/fake" "$tmp/bin/kpm" update 2>&1)
code=$?
[ "$code" -ne 0 ] && cmp -s "$repo/kpm" "$tmp/bin/kpm" && \
  cmp -s "$repo/xkraft" "$tmp/bin/xkraft" && check update_bad_hash 0 || check update_bad_hash 1

# Та же замена, но загрузка лежит на другой файловой системе.
if [ -d /dev/shm ] && [ -w /dev/shm ]; then
  (cd "$tmp/fake" && sha256sum kpm xkraft > SHA256SUMS)
  cp "$repo/kpm" "$tmp/bin/kpm"
  cp "$repo/xkraft" "$tmp/bin/xkraft"
  out=$(KRAFT_NO_UPDATE_CHECK=1 TMPDIR=/dev/shm KPM_UPDATE_DOWNLOAD="$tmp/fake" \
    "$tmp/bin/kpm" update 2>&1)
  code=$?
  [ "$code" -eq 0 ] && cmp -s "$tmp/fake/kpm" "$tmp/bin/kpm" && \
    cmp -s "$tmp/fake/xkraft" "$tmp/bin/xkraft" && \
    check update_cross_device 0 || check update_cross_device 1
else
  echo "skip   update_cross_device (нет /dev/shm)"
fi

echo "---"
echo "$total/$total kpm checks (fail=$fail)"
[ "$fail" -eq 0 ]
