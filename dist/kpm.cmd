@echo off
set "XKRAFT=%~dp0xkraft.cmd"
luajit "%~dp0kpm-win.lua" %*
