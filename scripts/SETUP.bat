@echo off
REM Dice Dungeon - GUI Installer

REM Run the GUI installer (no console window needed with pythonw)
cd ..
if exist "%LOCALAPPDATA%\Programs\Python\Python311\pythonw.exe" (
    start "" "%LOCALAPPDATA%\Programs\Python\Python311\pythonw.exe" scripts\setup.py
) else (
    start "" pythonw scripts\setup.py 2>nul || start "" python scripts\setup.py
)

exit
