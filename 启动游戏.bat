@echo off
rem ============================================================
rem  You Have My Word - one-click launcher
rem  Double-click this file to start the game directly.
rem ============================================================
setlocal
rem %~dp0 ends with a backslash, appending a dot keeps the
rem closing quote safe:  --path "C://...//YouHaveMyWord//."
start "YouHaveMyWord" "%~dp0_engine\Godot_v4.3-stable_win64.exe" --path "%~dp0."
endlocal
