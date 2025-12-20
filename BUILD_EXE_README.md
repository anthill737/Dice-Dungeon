# Building the EXE for Distribution

Run this once to create the DiceDungeon.exe that will be included in the repo.

## Steps:

1. Make sure all your game code is working
2. Run this script:
   ```bash
   python build_exe.py
   ```

3. The EXE will be created in `dist/DiceDungeon.exe`

4. Commit it to GitHub:
   ```bash
   git add dist/DiceDungeon.exe
   git commit -m "Add pre-built executable"
   git push
   ```

5. Users will now download the repo with the EXE already included!

## When to Rebuild:

Rebuild the EXE whenever you:
- Update game code
- Fix bugs
- Add new features
- Change assets

Just run `python build_exe.py` again and commit the new EXE.
