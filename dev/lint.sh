#!/bin/sh
# xkraft lint — базовая проверка стиля Kraft из docs/style.md.
# Встраивается в dist/xkraft через make-dist.sh; тестируется отдельно.
#
# Переменные окружения:
#   KRAFT_LINT_LIBRARY=1  — только определить kl_lint(), не запускать.

kl_lint() {
  kl_status=0
  if [ $# -eq 0 ]; then
    set -- .
  fi

  kl_list=""
  for kl_path in "$@"; do
    if [ -d "$kl_path" ]; then
      kl_found=$(find "$kl_path" -type f -name '*.kraft' \
        ! -path '*/.git/*' ! -path '*/dist/*' ! -path '*/venv/*' \
        ! -path '*/packages/*' 2>/dev/null | sort)
    elif [ -f "$kl_path" ]; then
      kl_found=$kl_path
    else
      printf 'xkraft lint: нет файла %s\n' "$kl_path" >&2
      kl_status=1
      continue
    fi
    if [ -n "$kl_found" ]; then
      if [ -n "$kl_list" ]; then
        kl_list="$kl_list
$kl_found"
      else
        kl_list=$kl_found
      fi
    fi
  done

  if [ -z "$kl_list" ]; then
    if [ "$kl_status" -eq 0 ]; then
      echo "ok lint: 0 files checked"
    fi
    return "$kl_status"
  fi

  set -- $kl_list
  kl_count=$#
  awk -v count="$kl_count" '
    function report(msg) {
      printf "%s:%d: %s\n", FILENAME, FNR, msg
      bad = 1
    }
    function name_after(prefix,    s) {
      s = $0
      sub("^[^:]*:", "", s)
      return s
    }
    {
      text = $0

      if (text ~ /[ \t]+$/) report("trailing whitespace")

      if (index(text, "\t") > 0) report("tab in .kraft")

      indent = text
      sub(/[^ ].*$/, "", indent)
      if (text ~ /[^ ]/ && (length(indent) % 4) != 0)
        report("indent " length(indent) " is not a multiple of 4")

      if (match(text, /(func|method)[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
        name = substr(text, RSTART, RLENGTH)
        sub(/^(func|method)[ \t]+/, "", name)
        if (name !~ /^[a-z][a-z0-9_]*$/)
          report("func/method name " name " is not snake_case")
      }

      if (match(text, /model[ \t]+[A-Z][A-Za-z0-9]*[ \t]*:/)) {
        name = substr(text, RSTART, RLENGTH)
        sub(/^model[ \t]+/, "", name)
        sub(/[ \t]*:$/, "", name)
        if (name !~ /^[A-Z][A-Za-z0-9]*$/)
          report("model name " name " is not CapWords")
      }

      if (match(text, /(flint|str|bool|list|dict|froz|any|range)[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
        name = substr(text, RSTART, RLENGTH)
        sub(/^[a-z]+[ \t]+/, "", name)
        if (name !~ /^[a-z][a-z0-9_]*$/)
          report("variable " name " is not snake_case")
      }

      if (text ~ /^[ \t]*export([ \t]|$)/)
        report("export is not in the language")
      if (text ~ /std\/(fs|json|file)([^A-Za-z0-9_]|$)/)
        report("removed stdlib module")
      if (text ~ /(^|[^A-Za-z0-9_])(clamp|lerp|is_even)[ \t]*\(/)
        report("removed builtin")
      if (text ~ /(^|[^A-Za-z0-9_])(list|dict)[ \t]*\(/)
        report("list()/dict() casts do not exist")
    }
    END {
      if (bad) exit 1
      printf "ok lint: %d files checked\n", count
    }
  ' "$@" || kl_status=1
  return "$kl_status"
}

if [ "${KRAFT_LINT_LIBRARY:-}" != "1" ]; then
  kl_lint "$@"
  exit $?
fi
