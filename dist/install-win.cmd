@echo off
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
