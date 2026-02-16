# Building the EXE & Creating a GitHub Release

The EXE is too large for the Git repo (388+ MB), so it's distributed via **GitHub Releases**.

## Steps:

1. **Build the executable:**
   ```bash
   python scripts/build_exe.py
   ```

2. The EXE will be created at `dist/DiceDungeon.exe`

3. **Create a GitHub Release:**
   - Go to https://github.com/anthill737/Dice-Dungeon/releases
   - Click **"Draft a new release"**
   - Choose a tag (e.g., `v1.1.0`) → **"Create new tag"**
   - Set the title (e.g., `Dice Dungeon v1.1.0`)
   - Paste release notes from CHANGELOG.md
   - Drag `dist/DiceDungeon.exe` into the **"Attach binaries"** area
   - Click **"Publish release"**

4. Users download the EXE directly from the Releases page — no installer needed!

## When to Rebuild:

Rebuild the EXE whenever you:
- Update game code
- Fix bugs
- Add new features
- Change assets

Run `python scripts/build_exe.py` again and create a new release on GitHub.

## Important Notes

- `dist/` and `build/` are gitignored — never commit the EXE to the repo
- The EXE is a single self-contained file (PyInstaller `--onefile`)
- Save files are stored in `%APPDATA%/DiceDungeon/` so they persist across updates
- GitHub Releases has a 2 GB file size limit per asset (plenty of room)
