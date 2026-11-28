#!/bin/sh
# Собирает минимальный дистрибутив: один автономный исполняемый файл dist/xkraft.
# Внутрь вшивается рантайм dev/src/krt.lua, поэтому установленному xkraft не
# нужны исходники, папка dev/ или эталон kraft v0.1.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$root/.." && pwd)
version=$(cat "$repo/VERSION")
export KRAFT_VERSION="$version"

command -v luajit >/dev/null 2>&1 || {
  echo "make-dist: нужен LuaJIT (команда luajit в PATH)" >&2
  exit 1
}
[ -x "$root/kraft" ] || {
  echo "make-dist: нет $root/kraft — соберите репозиторий целиком" >&2
  exit 1
}

echo "dist: пересобираем xkraft.lua ..."
"$root/kraft" -c "$root/xkraft.kraft"
mkdir -p "$repo/dist"

# Документы копируются до сборки архивов, чтобы VERSION/CHANGELOG внутри
# kraft-win.zip совпадали с текущей версией.
for f in README.md LICENSE NOTICE VERSION CHANGELOG.md; do
  cp "$repo/$f" "$repo/dist/$f"
done

python3 - "$root" "$repo" <<'PY'
import hashlib
import os
import pathlib
import re
import subprocess
import sys
import zipfile

root = pathlib.Path(sys.argv[1])
repo = pathlib.Path(sys.argv[2])
version = os.environ["KRAFT_VERSION"]
lua = (root / "xkraft.lua").read_text()
update_sh = (root / "update.sh").read_text()
lint_sh = (root / "lint.sh").read_text()
krt = (root / "src/krt.lua").read_text()

# Prelude пишется на Kraft и собирается тем же xkraft; в дистрибутив вшивается
# уже готовый Lua-код её функций.
full = subprocess.check_output([
    str(root / "kraft"), str(root / "xkraft.kraft"),
    "--emit-lua", "--no-prelude", str(root / "prelude.kraft")
], text=True)
start = full.index("krt.run(function()\n") + len("krt.run(function()\n")
end = full.rindex("\nend)")
prelude_lines = []
for line in full[start:end].splitlines():
    if line.startswith("    "):
        line = line[4:]
    line = re.sub(r"\bv_(\d+)\b", r"prelude_v_\1", line)
    line = re.sub(r"\bf_(\d+)\b", r"prelude_f_\1", line)
    prelude_lines.append(line)
prelude = "\n".join(prelude_lines).rstrip() + "\n"
(root / "src/prelude.lua").write_text(prelude)

# Дистрибутив не должен зависеть от каталога, в котором его собрали.
lua = re.sub(r'local __KRAFT_SOURCE = "[^"]*"',
             'local __KRAFT_SOURCE = "xkraft.kraft"', lua, count=1)
lua = re.sub(r'krt\.SOURCE_PATH = "[^"]*"',
             'krt.SOURCE_PATH = "xkraft.kraft"', lua, count=1)

def find_read(path_suffix):
    for candidate in re.finditer(r'krt\.read_file\((v_\d+)\)', lua):
        path_var = candidate.group(1)
        if re.search(r'^\s+' + path_var + r' = .*"' + re.escape(path_suffix) + r'"', lua, re.M):
            return candidate
    return None

runtime_call = find_read("/src/krt.lua")
prelude_call = find_read("/src/prelude.lua")
if runtime_call is None:
    sys.exit("make-dist: не нашёл чтение рантайма в xkraft.lua — обновите make-dist.sh")
if prelude_call is None:
    sys.exit("make-dist: не нашёл чтение prelude в xkraft.lua — обновите make-dist.sh")
runtime_path = runtime_call.group(1)
prelude_path = prelude_call.group(1)
runtime_guard = "krt.file_exists(" + runtime_path + ")"
prelude_guard = "krt.file_exists(" + prelude_path + ")"
if runtime_guard not in lua or prelude_guard not in lua:
    sys.exit("make-dist: не нашёл проверки файлов рантайма/prelude — обновите make-dist.sh")
if "]==]" in krt or "]==]" in prelude:
    sys.exit("make-dist: встроенный код содержит разделитель ]==]")

anchor = 'local __KRAFT_SOURCE = "xkraft.kraft"\n'
if lua.count(anchor) != 1:
    sys.exit("make-dist: не нашёл объявление __KRAFT_SOURCE")

# Стандартная библиотека встраивается в рантайм каждой собранной программы:
# установленному xkraft не нужна папка stdlib на диске.
stdlib_entries = []
for name in ("fos", "cli", "math", "base"):
    src = (root / "stdlib" / (name + ".kraft")).read_text()
    if "]==]" in src or "]===[" in src:
        sys.exit("make-dist: встроенный stdlib содержит разделитель long-bracket")
    # Внешний рантайм уже лежит в [==[ ... ]==], поэтому внутри берём уровень выше.
    stdlib_entries.append('  ["./stdlib/%s.kraft"] = [===[\n%s]===]' % (name, src))
stdlib_lua = "krt.EMBEDDED_SOURCES = {\n" + ",\n".join(stdlib_entries) + "\n}\n"
if krt.count("\nreturn krt\n") != 1:
    sys.exit("make-dist: не нашёл 'return krt' в runtime")
krt_with_stdlib = krt.replace("\nreturn krt\n", "\n" + stdlib_lua + "return krt\n")

# Сам компилятор тоже должен видеть встроенный stdlib при разборе import_lib.
rt_open = "local krt = (function()\n"
rt_close = "\nend)()\n"
start = lua.find(rt_open)
end = lua.find(rt_close, start) if start >= 0 else -1
if start < 0 or end < 0:
    sys.exit("make-dist: не нашёл встроенный runtime компилятора")
insert_at = end + len(rt_close)
lua = lua[:insert_at] + stdlib_lua + lua[insert_at:]

runtime = "local __KRAFT_DIST_RUNTIME = [==[\n" + krt_with_stdlib + "]==]\n\n"
prelude_lua = "local __KRAFT_DIST_PRELUDE = [==[\n" + prelude + "]==]\n\n"
lua = lua.replace(anchor, anchor + runtime + prelude_lua, 1)
lua = lua.replace(runtime_guard, "true", 1)
lua = lua.replace(prelude_guard, "true", 1)
lua = lua.replace(runtime_call.group(0), "__KRAFT_DIST_RUNTIME", 1)
lua = lua.replace(prelude_call.group(0), "__KRAFT_DIST_PRELUDE", 1)
if "__KRAFT_EMBEDDED_COMPILER__" in lua:
    sys.exit("make-dist: метка встроенного компилятора уже встречается в Lua")

header = '''#!/bin/sh
# xkraft @VERSION@ — автономный компилятор Kraft.
# lua-код компилятора вшит ниже; внешних файлов и каталога src/ не нужно.
set -eu
KRAFT_VERSION='@VERSION@'
tmp=$(mktemp -d "${TMPDIR:-/tmp}/xkraft.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

@UPDATE_SH@

KRAFT_LINT_LIBRARY=1
@LINT_SH@
unset KRAFT_LINT_LIBRARY

awk 'seen { print } /^__KRAFT_EMBEDDED_COMPILER__$/ { seen = 1 }' "$0" > "$tmp/compiler.lua"

if [ "${1-}" = "--version" ]; then
  exec luajit "$tmp/compiler.lua" --version
fi
if [ "${1-}" = "--update" ]; then
  ku_update "$0" "$tmp"
  exit $?
fi
if [ "${1-}" = "lint" ] || [ "${1-}" = "--lint" ]; then
  shift
  kl_lint "$@"
  exit $?
fi

ku_check "$KRAFT_VERSION" "$tmp" || true

mode=run
flags=""
src=""
while [ $# -gt 0 ]; do
  case $1 in
    --tokens) flags="$flags --tokens"; mode=tokens; shift ;;
    -c) flags="$flags -c"; mode=compile; shift ;;
    --emit-lua) flags="$flags --emit-lua"; mode=emit; shift ;;
    --no-prelude) flags="$flags --no-prelude"; shift ;;
    *) src=$1; shift; break ;;
  esac
done

if [ -z "$src" ]; then
  echo "usage: xkraft [--version|--update|lint|--tokens|-c] file.kraft" >&2
  exit 1
fi

case "$mode" in
  compile)
    luajit "$tmp/compiler.lua" $flags "$src" >/dev/null
    case "$src" in
      *.kraft) chmod +x "${src%.kraft}.lua" 2>/dev/null || true ;;
    esac
    ;;
  tokens|emit)
    exec luajit "$tmp/compiler.lua" $flags "$src"
    ;;
  run)
    luajit "$tmp/compiler.lua" $flags "$src" > "$tmp/program.lua"
    exec luajit "$tmp/program.lua" "$@"
    ;;
esac
exit 0
'''

header = (header.replace("@VERSION@", version)
                .replace("@UPDATE_SH@", update_sh)
                .replace("@LINT_SH@", lint_sh))

out = repo / "dist" / "xkraft"
dist_text = header + "__KRAFT_EMBEDDED_COMPILER__\n" + lua
out.write_text(dist_text)
out.chmod(0o755)

# Windows: тот же встроенный компилятор без shell/awk-обвязки.
marker = "__KRAFT_EMBEDDED_COMPILER__\n"
if dist_text.count(marker) != 1:
    sys.exit("make-dist: не нашёл метку встроенного компилятора")
(repo / "dist" / "xkraft-win.lua").write_text(dist_text.split(marker, 1)[1])

# kpm: автономный Lua-скрипт с оболочкой, как у xkraft.
kpm_src = (root / "kpm.lua").read_text()
kpm_header = '''#!/bin/sh
# kpm @VERSION@ — менеджер пакетов Kraft.
set -eu
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/kpm.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
awk 'seen { print } /^__KPM_EMBEDDED__$/ { seen = 1 }' "$0" > "$tmp/kpm.lua"
XKRAFT="$dir/xkraft"
export XKRAFT
exec luajit "$tmp/kpm.lua" "$@"
'''
kpm_header = kpm_header.replace("@VERSION@", version)

kpm_out = repo / "dist" / "kpm"
kpm_out.write_text(kpm_header + "__KPM_EMBEDDED__\n" + kpm_src)
kpm_out.chmod(0o755)
(repo / "dist" / "kpm-win.lua").write_text(kpm_src)

kpm_cmd = '''@echo off
set "XKRAFT=%~dp0xkraft.cmd"
luajit "%~dp0kpm-win.lua" %*
'''

xkraft_cmd = r'''@echo off
setlocal EnableExtensions
set "XK_DIR=%~dp0"
set "XK_LUA=%XK_DIR%xkraft-win.lua"

if not exist "%XK_LUA%" (
  echo xkraft: missing %XK_LUA% 1>&2
  exit /b 1
)
where luajit >nul 2>&1
if errorlevel 1 (
  echo xkraft: LuaJIT is required 1>&2
  exit /b 1
)

set "XK_MODE=run"
set "XK_FLAGS="
set "XK_SRC="

:scan
if "%~1"=="" goto usage
if "%~1"=="--version" goto version
if "%~1"=="--update" goto update
if "%~1"=="lint" goto lint
if "%~1"=="--lint" goto lint
if "%~1"=="--no-prelude" (
  set "XK_FLAGS=%XK_FLAGS% --no-prelude"
  shift
  goto scan
)
if "%~1"=="-c" (
  set "XK_MODE=compile"
  set "XK_FLAGS=%XK_FLAGS% -c"
  shift
  goto scan
)
if "%~1"=="--tokens" (
  set "XK_MODE=tokens"
  set "XK_FLAGS=%XK_FLAGS% --tokens"
  shift
  goto scan
)
if "%~1"=="--emit-lua" (
  set "XK_MODE=emit"
  set "XK_FLAGS=%XK_FLAGS% --emit-lua"
  shift
  goto scan
)
set "XK_SRC=%~1"
shift
goto args

:version
luajit "%XK_LUA%" --version
exit /b %ERRORLEVEL%

:update
powershell -NoProfile -Command "param([string]$dir,[string]$base) $ErrorActionPreference='Stop'; if (-not $base) { $base='https://github.com/MIRV314/kraft-lang/releases/latest/download' }; $tmp=Join-Path $env:TEMP ('kraft-update-'+[guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Force $tmp | Out-Null; try { Invoke-WebRequest -Uri ($base+'/SHA256SUMS') -OutFile (Join-Path $tmp 'SHA256SUMS'); $want=(Get-Content (Join-Path $tmp 'SHA256SUMS') | Where-Object { $_ -match '\s+kraft-win\.zip$' } | ForEach-Object { ($_ -split '\s+')[0] } | Select-Object -First 1); Invoke-WebRequest -Uri ($base+'/kraft-win.zip') -OutFile (Join-Path $tmp 'kraft-win.zip'); $got=(Get-FileHash -Algorithm SHA256 (Join-Path $tmp 'kraft-win.zip')).Hash.ToLower(); if (-not $want -or $got -ne $want.ToLower()) { throw 'SHA256 mismatch' }; $u=Join-Path $tmp 'unpacked'; Expand-Archive -Force -Path (Join-Path $tmp 'kraft-win.zip') -DestinationPath $u; Copy-Item -Force (Join-Path $u 'xkraft-win.lua') $dir; Copy-Item -Force (Join-Path $u 'kpm-win.lua') $dir; Write-Host 'kraft: обновлены xkraft и kpm' } finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }" "%~dp0" "%KRAFT_UPDATE_DOWNLOAD%"
exit /b %ERRORLEVEL%

:lint
set "XK_LINT_PATHS="
:lint_collect
shift
if "%~1"=="" goto lint_run
set "XK_LINT_PATHS=%XK_LINT_PATHS% %1"
goto lint_collect
:lint_run
if "%XK_LINT_PATHS%"=="" set "XK_LINT_PATHS=."
powershell -NoProfile -Command "param([string]$paths) $files=@(); foreach($p in $paths.Split(' ')){ if(Test-Path $p -PathType Container){ $files += @(Get-ChildItem -Path $p -Recurse -Filter *.kraft -File | Where-Object { $_.FullName -notmatch '\\\\(\\.git|dist|venv|packages)\\\\' }) } elseif(Test-Path $p){ $files += @(Get-Item $p) } }; $bad=0; foreach($f in $files){ $n=0; foreach($line in @(Get-Content $f.FullName)){ $n++; $msg=@(); if($line -match '[ \\t]+$'){ $msg+='trailing whitespace' }; if($line.Contains([char]9)){ $msg+='tab in .kraft' }; $indent=($line -replace '[^ ].*$','').Length; if($line -match '[^ ]' -and $indent % 4 -ne 0){ $msg+=('indent '+$indent+' is not a multiple of 4') }; if($line -match '(func|method|async)\\s+([A-Za-z_]\\w*)'){ $name=$Matches[2]; if($name -notmatch '^[a-z][a-z0-9_]*$'){ $msg+=('func/method name '+$name+' is not snake_case') } }; if($line -match 'model\\s+([A-Z][A-Za-z0-9]*)\\s*:'){ $name=$Matches[1]; if($name -notmatch '^[A-Z][A-Za-z0-9]*$'){ $msg+=('model name '+$name+' is not CapWords') } }; if($line -match '(flint|str|bool|list|dict|froz|any|range)\\s+([A-Za-z_]\\w*)'){ $name=$Matches[2]; if($name -notmatch '^[a-z][a-z0-9_]*$'){ $msg+=('variable '+$name+' is not snake_case') } }; if($line -match '^\\s*export(\\s|$)'){ $msg+='export is not in the language' }; if($line -match 'std/(fs|json|file)([^A-Za-z0-9_]|$)'){ $msg+='removed stdlib module' }; if($line -match '(^|[^A-Za-z0-9_])(clamp|lerp|is_even)\\s*\\('){ $msg+='removed builtin' }; if($line -match '(^|[^A-Za-z0-9_])(list|dict)\\s*\\('){ $msg+='list()/dict() casts do not exist' }; foreach($m in $msg){ Write-Host ($f.FullName+':'+$n+': '+$m); $bad=1 } } }; if($bad){ exit 1 }; Write-Host ('ok lint: '+$files.Count+' files checked')" "%XK_LINT_PATHS%"
exit /b %ERRORLEVEL%

:args
set "XK_ARGS="
:collect
if "%~1"=="" goto dispatch
set "XK_ARGS=%XK_ARGS% %1"
shift
goto collect

:dispatch
if "%XK_SRC%"=="" goto usage
if "%XK_MODE%"=="run" goto run
luajit "%XK_LUA%" %XK_FLAGS% "%XK_SRC%"
exit /b %ERRORLEVEL%

:run
set "XK_TMP=%TEMP%\xkraft_%RANDOM%_%RANDOM%.lua"
luajit "%XK_LUA%" %XK_FLAGS% "%XK_SRC%" > "%XK_TMP%"
if errorlevel 1 goto compile_failed
luajit "%XK_TMP%" %XK_ARGS%
set "XK_CODE=%ERRORLEVEL%"
del "%XK_TMP%" >nul 2>&1
exit /b %XK_CODE%

:compile_failed
del "%XK_TMP%" >nul 2>&1
exit /b 1

:usage
echo usage: xkraft [--version|--update|lint|--tokens|-c|--emit-lua] file.kraft [args...] 1>&2
exit /b 1
'''

kraft_cmd = r'''@echo off
call "%~dp0xkraft.cmd" %*
exit /b %ERRORLEVEL%
'''

install_win_cmd = r'''@echo off
setlocal EnableExtensions
where luajit >nul 2>&1
if errorlevel 1 (
  echo install: LuaJIT is required 1>&2
  exit /b 1
)

set "SRC=%~dp0"
if defined KRAFT_BIN (
  set "DEST=%KRAFT_BIN%"
) else (
  set "DEST=%LOCALAPPDATA%\Programs\kraft"
)

if not exist "%DEST%" mkdir "%DEST%"
if errorlevel 1 goto fail

copy /Y "%SRC%xkraft-win.lua" "%DEST%\xkraft-win.lua" >nul
if errorlevel 1 goto fail
copy /Y "%SRC%xkraft.cmd" "%DEST%\xkraft.cmd" >nul
if errorlevel 1 goto fail
copy /Y "%SRC%kraft.cmd" "%DEST%\kraft.cmd" >nul
if errorlevel 1 goto fail
copy /Y "%SRC%kpm-win.lua" "%DEST%\kpm-win.lua" >nul
if errorlevel 1 goto fail
copy /Y "%SRC%kpm.cmd" "%DEST%\kpm.cmd" >nul
if errorlevel 1 goto fail
for %%F in (README.md LICENSE NOTICE VERSION CHANGELOG.md) do (
  if exist "%SRC%%%F" copy /Y "%SRC%%%F" "%DEST%\%%F" >nul
)

powershell -NoProfile -Command "param([string]$dir) $p = [Environment]::GetEnvironmentVariable('Path','User'); if ($p -notlike ('*' + $dir + '*')) { [Environment]::SetEnvironmentVariable('Path', ($p.TrimEnd(';') + ';' + $dir), 'User'); Write-Host 'install: added to user PATH; restart the terminal' }" "%DEST%"
if errorlevel 1 echo install: could not update PATH; add %DEST% manually

"%DEST%\xkraft.cmd" --version
if errorlevel 1 goto fail

echo xkraft installed.
echo   commands: %DEST%\xkraft.cmd and %DEST%\kraft.cmd
exit /b 0

:fail
echo install: failed 1>&2
exit /b 1
'''

for name, text in [
    ("xkraft.cmd", xkraft_cmd),
    ("kraft.cmd", kraft_cmd),
    ("kpm.cmd", kpm_cmd),
    ("install-win.cmd", install_win_cmd),
]:
    (repo / "dist" / name).write_bytes(text.replace("\n", "\r\n").encode("utf-8"))

win_assets = ["xkraft-win.lua", "xkraft.cmd", "kraft.cmd", "kpm-win.lua",
              "kpm.cmd", "install-win.cmd", "README.md", "LICENSE", "NOTICE",
              "VERSION", "CHANGELOG.md"]
# Фиксируем время и атрибуты: иначе mtime перезаписанных файлов попадает в zip,
# и повторная сборка меняет SHA256SUMS (CI ловит это через git diff --exit-code).
with zipfile.ZipFile(repo / "dist" / "kraft-win.zip", "w", zipfile.ZIP_DEFLATED) as z:
    for name in win_assets:
        path = repo / "dist" / name
        if not path.exists():
            continue
        info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.create_system = 0
        info.external_attr = 0o644 << 16
        z.writestr(info, path.read_bytes())

checksum_lines = []
for name in ["xkraft", "kpm", "kraft-win.zip"]:
    digest = hashlib.sha256((repo / "dist" / name).read_bytes()).hexdigest()
    checksum_lines.append(f"{digest}  {name}\n")
(repo / "dist" / "SHA256SUMS").write_text("".join(checksum_lines))
PY

# Корневой xkraft — тот же бинарник, что и в dist/.
cp "$repo/dist/xkraft" "$repo/xkraft"
chmod 755 "$repo/xkraft"
cp "$repo/dist/kpm" "$repo/kpm"
chmod 755 "$repo/kpm"

# Windows-вариант — тот же встроенный Lua; проверяем, что он запускается.
luajit "$repo/dist/xkraft-win.lua" --version >/dev/null

echo "dist: готово — dist/xkraft ($(wc -c < "$repo/dist/xkraft") байт)"
