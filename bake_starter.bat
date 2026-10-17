@echo off
rem Bakes the starter town tile (3,4) and its eight neighbors on this computer.
rem One-time setup: set GODOT below to your Godot 4.7.2 program (the one you run the game with).
rem Then double-click this file. It takes about 5 to 10 minutes.

set GODOT=C:\Godot\Godot_v4.7.2-stable_win64_console.exe

if not exist "%GODOT%" (
  echo Godot was not found at: %GODOT%
  echo Open this file in Notepad and set the GODOT line to your Godot console program.
  pause
  exit /b 1
)

cd /d "%~dp0"
"%GODOT%" --headless --path . --script res://src/worldgen/tools/bake_tiles.gd -- "--tiles=2,3;2,4;2,5;3,3;3,4;3,5;4,3;4,4;4,5"

echo.
echo Finished. Now open GitHub Desktop: commit worlds/base_world/tiles/tile_3_4.tile and push.
echo Then tell Claude it is pushed.
pause
