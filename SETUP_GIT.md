# Git Repository Setup Guide

## First Time Setup

### 1. Initialize Git Repository
```powershell
cd dice-dungeon-github
git init
```

### 2. Add All Files
```powershell
git add .
```

### 3. Create Initial Commit
```powershell
git commit -m "Initial commit - Dice Dungeon Explorer v1.0"
```

### 4. Create GitHub Repository
1. Go to https://github.com/new
2. Create a new repository (e.g., "dice-dungeon")
3. Don't initialize with README (we already have one)
4. Copy the repository URL

### 5. Connect to GitHub
```powershell
git remote add origin https://github.com/YOUR_USERNAME/dice-dungeon.git
git branch -M main
git push -u origin main
```

## Updating After Changes

When I make changes to files, run these commands from the `dice-dungeon-github` folder:

### 1. Check What Changed
```powershell
git status
```

### 2. Add Changed Files
```powershell
# Add all changes
git add .

# Or add specific files
git add dice_dungeon_explorer.py
git add explorer/combat.py
```

### 3. Commit Changes
```powershell
git commit -m "Description of changes"
```

Example commit messages:
- `git commit -m "Fix: Combat message sequencing improvements"`
- `git commit -m "Fix: Target button highlighting for spawned enemies"`
- `git commit -m "Feature: Enemy sprites update when selecting targets"`
- `git commit -m "Remove: Garden Shears item (no functionality)"`

### 4. Push to GitHub
```powershell
git push
```

## Quick Update Script

Save this as a PowerShell script to quickly update:

```powershell
# update_repo.ps1
git add .
git commit -m "$args"
git push
```

Usage: `.\update_repo.ps1 "Your commit message"`

## Common Git Commands

```powershell
# View commit history
git log --oneline

# View changes before committing
git diff

# Undo last commit (keep changes)
git reset --soft HEAD~1

# View remote repository
git remote -v

# Pull latest changes (if collaborating)
git pull
```

## .gitignore Already Configured

The `.gitignore` file is already set up to exclude:
- Save files
- Debug logs
- Python cache files
- Personal settings

## Branching (Optional)

For feature development:
```powershell
# Create and switch to new branch
git checkout -b feature-name

# Push branch to GitHub
git push -u origin feature-name

# Switch back to main
git checkout main

# Merge feature into main
git merge feature-name
```
