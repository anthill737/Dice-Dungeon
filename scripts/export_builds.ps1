#Requires -Version 5.1
<#
.SYNOPSIS
    Export Dice Dungeon builds for Linux and Windows using Godot 4.
.DESCRIPTION
    Runs Godot headless import and exports both Linux/X11 and Windows Desktop
    presets. Output goes to godot_port/exports/.
.PARAMETER GodotBin
    Path to the Godot executable. Defaults to "godot" on PATH.
#>
param(
    [string]$GodotBin = "godot"
)

$ErrorActionPreference = "Stop"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Resolve-Path (Join-Path $ScriptDir "..\godot_port")
$ExportDir  = Join-Path $ProjectDir "exports"

if (-not (Get-Command $GodotBin -ErrorAction SilentlyContinue)) {
    Write-Error "Godot binary not found. Install Godot 4.3+ and ensure 'godot' is on PATH, or pass -GodotBin <path>."
    exit 1
}

Write-Host "==> Using Godot: $GodotBin"
& $GodotBin --version

if (-not (Test-Path $ExportDir)) {
    New-Item -ItemType Directory -Path $ExportDir | Out-Null
}

Write-Host ""
Write-Host "==> Importing project resources (headless)..."
& $GodotBin --headless --path $ProjectDir --import 2>&1 | Out-Null
Write-Host "    Import complete."

Write-Host ""
Write-Host "==> Exporting Linux/X11..."
& $GodotBin --headless --path $ProjectDir --export-release "Linux/X11" "$ExportDir\DiceDungeon_linux.x86_64"
Write-Host "    -> $ExportDir\DiceDungeon_linux.x86_64"

Write-Host ""
Write-Host "==> Exporting Windows Desktop..."
& $GodotBin --headless --path $ProjectDir --export-release "Windows Desktop" "$ExportDir\DiceDungeon_windows.exe"
Write-Host "    -> $ExportDir\DiceDungeon_windows.exe"

Write-Host ""
Write-Host "=== Export complete ==="
Write-Host "Builds are in: $ExportDir\"
Get-ChildItem $ExportDir | Format-Table Name, Length -AutoSize
