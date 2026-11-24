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
echo usage: xkraft [--tokens] [-c] [--emit-lua] file.kraft [args...] 1>&2
exit /b 1
