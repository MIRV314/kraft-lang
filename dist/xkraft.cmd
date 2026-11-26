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
echo usage: xkraft [--version|--update|--tokens|-c|--emit-lua] file.kraft [args...] 1>&2
exit /b 1
