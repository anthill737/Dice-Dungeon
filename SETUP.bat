@echo off
REM Dice Dungeon Explorer - GUI Installer

REM Run the GUI installer (no console window needed with pythonw)
if exist "%LOCALAPPDATA%\Programs\Python\Python311\pythonw.exe" (
    start "" "%LOCALAPPDATA%\Programs\Python\Python311\pythonw.exe" setup.py
) else (
    start "" pythonw setup.py 2>nul || start "" python setup.py
)

exit
