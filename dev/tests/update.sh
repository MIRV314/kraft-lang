#!/bin/sh
# Обновление xkraft: локальный фейковый релиз, без сети.
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
mkdir -p "$tmp/fake"

printf '#!/bin/sh\necho UPDATED\n' > "$tmp/fake/xkraft"
chmod 755 "$tmp/fake/xkraft"
good=$(sha256sum "$tmp/fake/xkraft" | awk '{print $1}')
printf '%s  xkraft\n' "$good" > "$tmp/fake/SHA256SUMS"

out=$(KRAFT_NO_UPDATE_CHECK=1 KRAFT_UPDATE_DOWNLOAD="$tmp/fake" \
  "$tmp/xkraft" --update 2>&1)
code=$?
[ "$code" -eq 0 ] && [ "$out" = "xkraft: обновлено" ]
check "xkraft-update-ok" $?
cmp -s "$tmp/fake/xkraft" "$tmp/xkraft"
check "xkraft-update-replaced" $?

# Загрузка с другой ФС: mv из каталога загрузки в каталог бинарника
# должен работать через копию во временный файл рядом с целью.
if [ -d /dev/shm ] && [ -w /dev/shm ]; then
  cp ../xkraft "$tmp/xkraft-cross"
  out=$(KRAFT_NO_UPDATE_CHECK=1 TMPDIR=/dev/shm KRAFT_UPDATE_DOWNLOAD="$tmp/fake" \
    "$tmp/xkraft-cross" --update 2>&1)
  code=$?
  [ "$code" -eq 0 ] && [ "$out" = "xkraft: обновлено" ] && \
    cmp -s "$tmp/fake/xkraft" "$tmp/xkraft-cross"
  check "xkraft-update-cross-device" $?
else
  echo "skip   xkraft-update-cross-device (нет /dev/shm)"
fi

# Подмена хэша: файл должен остаться прежним.
cp ../xkraft "$tmp/xkraft-bad"
printf '%s  xkraft\n' "$(printf '%064d' 0)" > "$tmp/fake/SHA256SUMS"
out=$(KRAFT_NO_UPDATE_CHECK=1 KRAFT_UPDATE_DOWNLOAD="$tmp/fake" \
  "$tmp/xkraft-bad" --update 2>&1)
code=$?
[ "$code" -ne 0 ]
check "xkraft-update-bad-hash-fails" $?
cmp -s ../xkraft "$tmp/xkraft-bad"
check "xkraft-update-bad-hash-keeps-file" $?

out=$(KRAFT_NO_UPDATE_CHECK=1 "$tmp/xkraft-bad" --version)
[ "$out" = "xkraft 0.9.0" ]
check "xkraft-update-version" $?

echo "---"
echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
