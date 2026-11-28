#!/bin/sh
# Обновление kraft: единственная команда меняет xkraft и kpm вместе.
# Локальный фейковый релиз, без сети.
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

cp ../xkraft "$tmp/xkraft"
cp ../kpm "$tmp/kpm"
mkdir -p "$tmp/fake"

printf '#!/bin/sh\necho UPDATED-XKRAFT\n' > "$tmp/fake/xkraft"
printf '#!/bin/sh\necho UPDATED-KPM\n' > "$tmp/fake/kpm"
chmod 755 "$tmp/fake/xkraft" "$tmp/fake/kpm"
(cd "$tmp/fake" && sha256sum kpm xkraft > SHA256SUMS)

out=$(KRAFT_NO_UPDATE_CHECK=1 KRAFT_UPDATE_DOWNLOAD="$tmp/fake" \
  "$tmp/xkraft" --update 2>&1)
code=$?
[ "$code" -eq 0 ] && [ "$out" = "kraft: обновлены xkraft и kpm" ]
check "kraft-update-ok" $?
cmp -s "$tmp/fake/xkraft" "$tmp/xkraft" && cmp -s "$tmp/fake/kpm" "$tmp/kpm"
check "kraft-update-replaced-both" $?

# Загрузка с другой ФС: mv из каталога загрузки в каталог бинарника
# должен работать через копию во временный файл рядом с целью.
if [ -d /dev/shm ] && [ -w /dev/shm ]; then
  mkdir -p "$tmp/cross"
  cp ../xkraft "$tmp/cross/xkraft"
  cp ../kpm "$tmp/cross/kpm"
  out=$(KRAFT_NO_UPDATE_CHECK=1 TMPDIR=/dev/shm KRAFT_UPDATE_DOWNLOAD="$tmp/fake" \
    "$tmp/cross/xkraft" --update 2>&1)
  code=$?
  [ "$code" -eq 0 ] && [ "$out" = "kraft: обновлены xkraft и kpm" ] && \
    cmp -s "$tmp/fake/xkraft" "$tmp/cross/xkraft" && \
    cmp -s "$tmp/fake/kpm" "$tmp/cross/kpm"
  check "kraft-update-cross-device" $?
else
  echo "skip   kraft-update-cross-device (нет /dev/shm)"
fi

# Подмена хэша: оба файла остаются прежними.
mkdir -p "$tmp/bad"
cp ../xkraft "$tmp/bad/xkraft"
cp ../kpm "$tmp/bad/kpm"
printf '%s  kpm\n' "$(printf '%064d' 0)" > "$tmp/fake/SHA256SUMS"
sha256sum "$tmp/fake/xkraft" | sed 's|  .*|  xkraft|' >> "$tmp/fake/SHA256SUMS"
out=$(KRAFT_NO_UPDATE_CHECK=1 KRAFT_UPDATE_DOWNLOAD="$tmp/fake" \
  "$tmp/bad/xkraft" --update 2>&1)
code=$?
[ "$code" -ne 0 ]
check "kraft-update-bad-hash-fails" $?
cmp -s ../xkraft "$tmp/bad/xkraft" && cmp -s ../kpm "$tmp/bad/kpm"
check "kraft-update-bad-hash-keeps-both" $?

out=$(KRAFT_NO_UPDATE_CHECK=1 "$tmp/bad/xkraft" --version)
[ "$out" = "xkraft 0.9.4" ]
check "kraft-update-version" $?

echo "---"
echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
