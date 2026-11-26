# Обновление xkraft из GitHub Releases.
# Встраивается в dist/xkraft через make-dist.sh; тестируется отдельно.
#
# Переменные окружения:
#   KRAFT_NO_UPDATE_CHECK=1   — отключить фоновую проверку версии;
#   KRAFT_UPDATE_API          — URL/файл с JSON последнего релиза;
#   KRAFT_UPDATE_DOWNLOAD     — URL/каталог с ассетами релиза;
#   KRAFT_UPDATE_CACHE        — файл времени последней проверки.

ku_api=${KRAFT_UPDATE_API:-https://api.github.com/repos/MIRV314/kraft-lang/releases/latest}
ku_download=${KRAFT_UPDATE_DOWNLOAD:-https://github.com/MIRV314/kraft-lang/releases/latest/download}

# http(s)/file — через curl, обычный путь — через cat (для тестов и зеркал).
ku_fetch() {
  case "$1" in
    http://*|https://*|file://*)
      curl -fsSL --connect-timeout 3 --max-time 15 "$1" -o "$2"
      ;;
    *)
      cat "$1" > "$2"
      ;;
  esac
}

ku_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    return 1
  fi
}

ku_latest_tag() {
  ku_fetch "$ku_api" "$1/release.json" || return 1
  ku_tag=$(sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$1/release.json" | head -n 1)
  [ -n "$ku_tag" ] || return 1
  printf '%s\n' "$ku_tag"
}

# Раз в сутки, только в интерактивном терминале, только при newer tag.
ku_check() {
  [ "${KRAFT_NO_UPDATE_CHECK:-}" = "1" ] && return 0
  [ -t 2 ] || return 0

  ku_cache=${KRAFT_UPDATE_CACHE:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/kraft/last-check}
  ku_now=$(date +%s 2>/dev/null || echo 0)
  ku_last=0
  if [ -f "$ku_cache" ]; then
    ku_last=$(cat "$ku_cache" 2>/dev/null || echo 0)
  fi
  case "$ku_last" in
    ''|*[!0-9]*) ku_last=0 ;;
  esac
  ku_age=$((ku_now - ku_last))
  [ "$ku_age" -lt 0 ] && ku_age=86400
  [ "$ku_age" -lt 86400 ] && return 0

  mkdir -p "$(dirname "$ku_cache")" 2>/dev/null || return 0
  printf '%s\n' "$ku_now" > "$ku_cache" 2>/dev/null || return 0

  ku_tag=$(ku_latest_tag "$2") || return 0
  if [ "$ku_tag" != "v$1" ]; then
    printf 'xkraft: доступна %s, запустите xkraft --update\n' "$ku_tag" >&2
  fi
  return 0
}

# Скачать SHA256SUMS и xkraft, сверить хэш, атомарно заменить файл.
ku_update() {
  ku_fetch "$ku_download/SHA256SUMS" "$2/SHA256SUMS" || {
    printf 'xkraft: не могу получить SHA256SUMS\n' >&2
    return 1
  }
  ku_want=$(awk '$2 == "xkraft" { print $1; exit }' "$2/SHA256SUMS")
  if [ -z "$ku_want" ]; then
    printf 'xkraft: в SHA256SUMS нет xkraft\n' >&2
    return 1
  fi

  ku_fetch "$ku_download/xkraft" "$2/xkraft.new" || {
    printf 'xkraft: не могу скачать xkraft\n' >&2
    return 1
  }
  ku_got=$(ku_hash "$2/xkraft.new") || {
    printf 'xkraft: нет sha256sum или shasum\n' >&2
    return 1
  }
  if [ "$ku_got" != "$ku_want" ]; then
    printf 'xkraft: не совпал SHA256, обновление отменено\n' >&2
    return 1
  fi

  chmod 755 "$2/xkraft.new" || return 1
  mv -f "$2/xkraft.new" "$1" || {
    printf 'xkraft: не могу заменить %s\n' "$1" >&2
    return 1
  }
  printf 'xkraft: обновлено\n'
  return 0
}
