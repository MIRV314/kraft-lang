#!/bin/sh
# Базовый проверяющий стиля: НЕ входит в make check и не попадает в dist.
# Запуск вручную: dev/tests/style.sh. Источник правил — docs/style.md.
set -u
cd "$(dirname "$0")/../.." || exit 1

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

python3 - > "$tmp/style.out" 2>&1 <<'PY'
import pathlib
import re
import sys

root = pathlib.Path('.')
skip_dirs = {'.git', 'dist', 'venv', 'packages'}
skip_files = {'xkraft.lua', 'krt.lua', 'prelude.lua'}

files = []
for p in root.rglob('*'):
    if not p.is_file() or any(part in skip_dirs for part in p.parts):
        continue
    if p.name in skip_files or p.suffix in {'.lua', '.zip', '.png'}:
        continue
    # .out/.stdin и т.п. — ожидаемые данные тестов, а не исходники.
    if p.suffix in {'.out', '.code', '.stdin', '.argv', '.selfonly'}:
        continue
    try:
        data = p.read_text()
    except UnicodeDecodeError:
        continue
    files.append((p, data))

kraft = [(p, d) for p, d in files if p.suffix == '.kraft']
# Пользовательские программы. Исходник компилятора и prelude не проверяем:
# там те же имена встречаются в строках и диагностике. В err_* нарушения
# намеренные — это фикстуры тестов.
users = []
for p, d in kraft:
    s = str(p).replace('\\', '/')
    if not (s.startswith('examples/') or s.startswith('dev/stdlib/')
            or s.startswith('dev/tests/')):
        continue
    if p.name.startswith('err_') and 'tests' in p.parts:
        continue
    users.append((p, d))

problems = []

def report(p, n, text):
    problems.append('%s:%d: %s' % (p, n, text))

for p, data in files:
    for n, line in enumerate(data.splitlines(), 1):
        if line.rstrip(' \t') != line:
            report(p, n, 'trailing whitespace')

for p, data in kraft:
    for n, line in enumerate(data.splitlines(), 1):
        if '\t' in line:
            report(p, n, 'tab in .kraft')
        indent = len(line) - len(line.lstrip(' '))
        if line.strip() and indent % 4:
            report(p, n, 'indent %d is not a multiple of 4' % indent)

name_func = re.compile(r'^\s*(?:func|method)\s+([A-Za-z_]\w*)\s*\(')
name_model = re.compile(r'^\s*model\s+([A-Za-z_]\w*)\s*:')
name_var = re.compile(r'^\s*(?:flint|str|bool|list|dict|froz|any|range)\s+([A-Za-z_]\w*)\s*(?:=|:|$)')
for p, data in kraft:
    if p.name.startswith('err_') and 'tests' in p.parts:
        continue
    for n, line in enumerate(data.splitlines(), 1):
        m = name_func.match(line)
        if m and not re.match(r'^[a-z][a-z0-9_]*$', m.group(1)):
            report(p, n, 'func/method name %s is not snake_case' % m.group(1))
        m = name_model.match(line)
        if m and not re.match(r'^[A-Z][A-Za-z0-9]*$', m.group(1)):
            report(p, n, 'model name %s is not CapWords' % m.group(1))
        m = name_var.match(line)
        if m and not re.match(r'^[a-z][a-z0-9_]*$', m.group(1)):
            report(p, n, 'variable %s is not snake_case' % m.group(1))

forbidden = [
    (re.compile(r'^\s*export\b'), 'export is not in the language'),
    (re.compile(r'std/(?:math|fs|json|file)\b'), 'removed stdlib module'),
    (re.compile(r'\b(?:clamp|lerp|is_even)\s*\('), 'removed builtin'),
    (re.compile(r'\b(?:list|dict)\s*\('), 'list()/dict() casts do not exist'),
]
for p, data in users:
    for n, line in enumerate(data.splitlines(), 1):
        for pattern, why in forbidden:
            if pattern.search(line):
                report(p, n, why)

if problems:
    for line in problems[:80]:
        print(line)
    if len(problems) > 80:
        print('... and %d more' % (len(problems) - 80))
    sys.exit(1)
print('ok style: %d files checked' % len(files))
PY
code=$?
cat "$tmp/style.out"
if [ "$code" -eq 0 ]; then
  echo "ok   style"
else
  echo "FAIL style"
fi
exit "$code"
