# Quick update script for pushing changes to GitHub
# Usage: .\quick-update.ps1 "Your commit message"

param(
    [Parameter(Mandatory=$true)]
    [string]$CommitMessage
)

Write-Host "Checking for changes..." -ForegroundColor Cyan
git status

Write-Host "`nAdding all changes..." -ForegroundColor Cyan
git add .

Write-Host "`nCommitting changes..." -ForegroundColor Cyan
git commit -m $CommitMessage

Write-Host "`nPushing to GitHub..." -ForegroundColor Cyan
git push

Write-Host "`nDone! Repository updated." -ForegroundColor Green
