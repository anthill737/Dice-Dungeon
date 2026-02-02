@echo off
REM Dice Dungeon - GUI Installer

REM Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"
REM Remove trailing backslash and go up one level to project root
set "PROJECT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%PROJECT_DIR%") do set "PROJECT_DIR=%%~dpI"
REM Remove trailing backslash from project dir
set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

REM Change to project directory
cd /d "%PROJECT_DIR%"

echo Starting Dice Dungeon Installer...
echo Project directory: %PROJECT_DIR%

REM Try to run the GUI installer
REM First try pythonw (no console window), fall back to python if needed
if exist "%LOCALAPPDATA%\Programs\Python\Python313\pythonw.exe" (
    start "" "%LOCALAPPDATA%\Programs\Python\Python313\pythonw.exe" "%SCRIPT_DIR%setup.py"
) else if exist "%LOCALAPPDATA%\Programs\Python\Python312\pythonw.exe" (
    start "" "%LOCALAPPDATA%\Programs\Python\Python312\pythonw.exe" "%SCRIPT_DIR%setup.py"
) else if exist "%LOCALAPPDATA%\Programs\Python\Python311\pythonw.exe" (
    start "" "%LOCALAPPDATA%\Programs\Python\Python311\pythonw.exe" "%SCRIPT_DIR%setup.py"
) else (
    REM Try pythonw from PATH, fall back to python (which shows console but works)
    where pythonw >nul 2>nul
    if %ERRORLEVEL% EQU 0 (
        start "" pythonw "%SCRIPT_DIR%setup.py"
    ) else (
        REM Use python with visible console as fallback
        echo Python GUI launcher not found, using console mode...
        python "%SCRIPT_DIR%setup.py"
        if %ERRORLEVEL% NEQ 0 (
            echo.
            echo ERROR: Python is not installed or not in PATH.
            echo Please install Python from https://www.python.org/downloads/
            echo Make sure to check "Add Python to PATH" during installation.
            echo.
            pause
        )
    )
)

exit
