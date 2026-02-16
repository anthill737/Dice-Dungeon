# Building the EXE for Distribution

The EXE is stored in the repo via **Git LFS** (Large File Storage) so users can download and install it directly.

## Steps:

1. Make sure all your game code is working
2. Run this script:
   ```bash
   python scripts/build_exe.py
   ```

3. The EXE will be created in `dist/DiceDungeon.exe`

4. Commit it to GitHub (Git LFS handles the large file automatically):
   ```bash
   git add dist/DiceDungeon.exe
   git commit -m "Update DiceDungeon.exe with latest build"
   git push
   ```

5. Users download the repo ZIP and run SETUP.bat to install!

## When to Rebuild:

Rebuild the EXE whenever you:
- Update game code
- Fix bugs
- Add new features
- Change assets

Just run `python scripts/build_exe.py` again and commit the new EXE.
