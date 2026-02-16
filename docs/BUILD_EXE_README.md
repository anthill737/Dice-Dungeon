# Building the EXE for Distribution

The EXE is too large for the Git repo (388+ MB), so it's hosted on **GitHub Releases**. The installer (`SETUP.bat` → `setup.py`) downloads it automatically.

## Steps:

1. Make sure all your game code is working
2. Run this script:
   ```bash
   python scripts/build_exe.py
   ```

3. The EXE will be created in `dist/DiceDungeon.exe`

4. Upload it as a GitHub Release:
   - Go to https://github.com/anthill737/Dice-Dungeon/releases
   - Click **"Draft a new release"**
   - Choose a tag (e.g., `v1.1.0`) → **"Create new tag"**
   - Set the title (e.g., `Dice Dungeon v1.1.0`)
   - Drag `dist/DiceDungeon.exe` into the **"Attach binaries"** area
   - Click **"Publish release"**

5. Users download the repo ZIP, run SETUP.bat, and the installer downloads the EXE for them!

## When to Rebuild:

Rebuild the EXE whenever you:
- Update game code
- Fix bugs
- Add new features
- Change assets

Run `python scripts/build_exe.py` again and create a new release on GitHub.
