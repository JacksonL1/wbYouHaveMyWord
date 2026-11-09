@echo off
rem ============================================================
rem  You Have My Word - open the Godot editor for this project
rem ============================================================
setlocal
rem %~dp0 ends with a backslash, appending a dot keeps the
rem closing quote safe:  --path "C://...//YouHaveMyWord//."
start "YouHaveMyWordEditor" "%~dp0_engine\Godot_v4.3-stable_win64.exe" -e --path "%~dp0."
endlocal
