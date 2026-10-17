@echo off
rem Bakes the starter town tile (3,4) and its eight neighbors on this computer.
rem Just double-click it. It finds your Godot by itself the first time and remembers it.
rem (If it cannot find Godot, drag your Godot program onto this file once.)
rem Takes about 5 to 10 minutes.

cd /d "%~dp0"
set GODOT=

rem 1. Dragged-on program, else the remembered one.
if not "%~1"=="" set GODOT=%~1
if "%GODOT%"=="" if exist godot_path.txt set /p GODOT=<godot_path.txt

rem 2. Look in the usual places (the console version is preferred).
if "%GODOT%"=="" for %%R in ("%USERPROFILE%\Downloads" "%USERPROFILE%\Desktop" "C:\Godot" "C:\GodotProjects" "C:\Program Files\Godot" "%LOCALAPPDATA%\Godot") do (
  if "%GODOT%"=="" if exist "%%~R" for /f "delims=" %%F in ('dir /s /b "%%~R\Godot*console*.exe" 2^>nul') do if "%GODOT%"=="" set GODOT=%%F
)
if "%GODOT%"=="" for %%R in ("%USERPROFILE%\Downloads" "%USERPROFILE%\Desktop" "C:\Godot" "C:\GodotProjects" "C:\Program Files\Godot" "%LOCALAPPDATA%\Godot") do (
  if "%GODOT%"=="" if exist "%%~R" for /f "delims=" %%F in ('dir /s /b "%%~R\Godot*.exe" 2^>nul') do if "%GODOT%"=="" set GODOT=%%F
)

if "%GODOT%"=="" (
  echo Could not find Godot. Drag your Godot program onto bake_starter.bat once.
  pause
  exit /b 1
)

echo Using Godot: %GODOT%
>godot_path.txt echo %GODOT%

"%GODOT%" --headless --path . --script res://src/worldgen/tools/bake_tiles.gd -- "--tiles=2,3;2,4;2,5;3,3;3,4;3,5;4,3;4,4;4,5"

echo.
echo Finished. Now open GitHub Desktop: commit worlds/base_world/tiles/tile_3_4.tile and push.
echo Then tell Claude it is pushed.
pause
