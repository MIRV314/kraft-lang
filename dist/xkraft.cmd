@echo off
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
powershell -NoProfile -Command "param([string]$dir,[string]$base) $ErrorActionPreference='Stop'; if (-not $base) { $base='https://github.com/MIRV314/kraft-lang/releases/latest/download' }; $tmp=Join-Path $env:TEMP ('kraft-update-'+[guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Force $tmp | Out-Null; try { Invoke-WebRequest -Uri ($base+'/SHA256SUMS') -OutFile (Join-Path $tmp 'SHA256SUMS'); $want=(Get-Content (Join-Path $tmp 'SHA256SUMS') | Where-Object { $_ -match '\s+kraft-win\.zip$' } | ForEach-Object { ($_ -split '\s+')[0] } | Select-Object -First 1); Invoke-WebRequest -Uri ($base+'/kraft-win.zip') -OutFile (Join-Path $tmp 'kraft-win.zip'); $got=(Get-FileHash -Algorithm SHA256 (Join-Path $tmp 'kraft-win.zip')).Hash.ToLower(); if (-not $want -or $got -ne $want.ToLower()) { throw 'SHA256 mismatch' }; $u=Join-Path $tmp 'unpacked'; Expand-Archive -Force -Path (Join-Path $tmp 'kraft-win.zip') -DestinationPath $u; Copy-Item -Force (Join-Path $u 'xkraft-win.lua') $dir; Copy-Item -Force (Join-Path $u 'kpm-win.lua') $dir; Write-Host 'xkraft: обновлено' } finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }" "%~dp0" "%KRAFT_UPDATE_DOWNLOAD%"
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
powershell -NoProfile -Command "param([string]$paths) $files=@(); foreach($p in $paths.Split(' ')){ if(Test-Path $p -PathType Container){ $files += @(Get-ChildItem -Path $p -Recurse -Filter *.kraft -File | Where-Object { $_.FullName -notmatch '\\\\(\\.git|dist|venv|packages)\\\\' }) } elseif(Test-Path $p){ $files += @(Get-Item $p) } }; $bad=0; foreach($f in $files){ $n=0; foreach($line in @(Get-Content $f.FullName)){ $n++; $msg=@(); if($line -match '[ \\t]+$'){ $msg+='trailing whitespace' }; if($line.Contains([char]9)){ $msg+='tab in .kraft' }; $indent=($line -replace '[^ ].*$','').Length; if($line -match '[^ ]' -and $indent % 4 -ne 0){ $msg+=('indent '+$indent+' is not a multiple of 4') }; if($line -match '(func|method)\\s+([A-Za-z_]\\w*)'){ $name=$Matches[2]; if($name -notmatch '^[a-z][a-z0-9_]*$'){ $msg+=('func/method name '+$name+' is not snake_case') } }; if($line -match 'model\\s+([A-Z][A-Za-z0-9]*)\\s*:'){ $name=$Matches[1]; if($name -notmatch '^[A-Z][A-Za-z0-9]*$'){ $msg+=('model name '+$name+' is not CapWords') } }; if($line -match '(flint|str|bool|list|dict|froz|any|range)\\s+([A-Za-z_]\\w*)'){ $name=$Matches[2]; if($name -notmatch '^[a-z][a-z0-9_]*$'){ $msg+=('variable '+$name+' is not snake_case') } }; if($line -match '^\\s*export(\\s|$)'){ $msg+='export is not in the language' }; if($line -match 'std/(math|fs|json|file)([^A-Za-z0-9_]|$)'){ $msg+='removed stdlib module' }; if($line -match '(^|[^A-Za-z0-9_])(clamp|lerp|is_even)\\s*\\('){ $msg+='removed builtin' }; if($line -match '(^|[^A-Za-z0-9_])(list|dict)\\s*\\('){ $msg+='list()/dict() casts do not exist' }; foreach($m in $msg){ Write-Host ($f.FullName+':'+$n+': '+$m); $bad=1 } } }; if($bad){ exit 1 }; Write-Host ('ok lint: '+$files.Count+' files checked')" "%XK_LINT_PATHS%"
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
