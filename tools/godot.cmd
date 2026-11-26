@echo off
rem Same shim for cmd/PowerShell: tools\godot.cmd --headless --path . --script ...
setlocal
if not defined GODOT_EXE set "GODOT_EXE=C:\DynastyLane\godot\godot_lane_a.exe"
"%GODOT_EXE%" %*
