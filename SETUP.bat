@echo off
REM Dice Dungeon - Quick Setup
REM Just double-click this file to start the installer!

REM Get the directory where this batch file is located
set "ROOT_DIR=%~dp0"

REM Launch the installer from the scripts folder
call "%ROOT_DIR%scripts\SETUP.bat"
