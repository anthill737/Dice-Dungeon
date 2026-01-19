# Creating GitHub Releases with Standalone EXE

This guide shows how to create downloadable releases on GitHub with pre-built executables for users who don't have Python.

## Option 1: Manual Release Creation

1. **Build the executable locally:**
   ```bash
   python scripts/build_exe.py
   ```

2. **Zip the portable folder:**
   ```bash
   # Windows PowerShell
   Compress-Archive -Path "DiceDungeon_Portable" -DestinationPath "DiceDungeon_v1.0_Windows.zip"
   
   # Mac/Linux
   zip -r DiceDungeon_v1.0_Windows.zip DiceDungeon_Portable/
   ```

3. **Create a GitHub release:**
   - Go to your repository on GitHub
   - Click "Releases" → "Create a new release"
   - Choose a tag (e.g., `v1.0.0`)
   - Add release notes
   - Upload the ZIP file
   - Publish!

## Option 2: Automated with GitHub Actions (Advanced)

Create `.github/workflows/build-release.yml`:

```yaml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: windows-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.11'
    
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install pyinstaller pillow
    
    - name: Build executable
      run: python scripts/build_exe.py
    
    - name: Create ZIP
      run: |
        Compress-Archive -Path "DiceDungeon_Portable" -DestinationPath "DiceDungeon_Windows.zip"
    
    - name: Create Release
      uses: softprops/action-gh-release@v1
      with:
        files: DiceDungeon_Windows.zip
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### How to use the automated workflow:

1. Copy the above YAML into `.github/workflows/build-release.yml`
2. Commit and push to GitHub
3. Create a new tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
4. GitHub automatically builds and creates a release!

## Release Checklist

Before creating a release:

- [ ] Update version number in `dice_dungeon_launcher.py`
- [ ] Update CHANGELOG.md with new changes
- [ ] Test the game thoroughly
- [ ] Build and test the EXE locally
- [ ] Write clear release notes
- [ ] Tag the commit properly (semantic versioning)

## Release Notes Template

```markdown
# Dice Dungeon v1.0.0

## 🎮 Play Now!

**Windows (No Python Required):**
Download `DiceDungeon_Windows.zip`, extract, and run `DiceDungeon.exe`

**All Platforms (With Python):**
See [INSTALL.md](INSTALL.md) for installation instructions.

## ✨ What's New

- Added 288 unique enemy sprites
- Implemented lore system
- New boss abilities
- Improved UI and settings

## 🐛 Bug Fixes

- Fixed save system crash
- Corrected dice roll calculation
- Improved memory usage

## 📝 Full Changelog

See [CHANGELOG.md](CHANGELOG.md) for complete details.

## 🆘 Support

Having issues? Check:
- [Installation Guide](INSTALL.md)
- [Quick Start](QUICKSTART.md)
- [GitHub Issues](https://github.com/yourusername/dice-dungeon/issues)
```

## Download Statistics

You can track downloads of your releases:
- Go to: `https://github.com/yourusername/dice-dungeon/releases`
- Each release shows download counts for each file

## Best Practices

1. **Semantic Versioning:**
   - `v1.0.0` - Major release
   - `v1.1.0` - New features
   - `v1.1.1` - Bug fixes

2. **File Naming:**
   - Include version: `DiceDungeon_v1.0.0_Windows.zip`
   - Include platform: `_Windows`, `_Mac`, `_Linux`
   - Be consistent!

3. **Release Frequency:**
   - Major releases: Every few months
   - Minor updates: As needed
   - Hotfixes: When critical bugs appear

4. **Pre-releases:**
   - Mark beta versions as "pre-release" on GitHub
   - Get community feedback before stable release

## Making Multi-Platform Releases

For cross-platform support:

**Windows:**
```bash
python scripts/build_exe.py
# Creates Windows .exe
```

**macOS:**
```bash
# Use PyInstaller on Mac
pyinstaller --name=DiceDungeon --windowed --onefile dice_dungeon_launcher.py
# Creates macOS .app bundle
```

**Linux:**
```bash
# Create AppImage or distribute as Python package
# Or use PyInstaller for a Linux binary
```

Each platform can have its own ZIP file in the release.

## Troubleshooting Build Issues

**"UPX is not available":**
- PyInstaller warning, safe to ignore
- Or install UPX for smaller executables

**"Module not found" in built EXE:**
- Add to build_exe.py:
  ```python
  --hidden-import=missing_module
  ```

**Antivirus false positives:**
- Common with PyInstaller EXEs
- Sign your executable (advanced)
- Explain in release notes

**Large file size:**
- Normal for Python apps (~50-100 MB)
- Includes Python interpreter and libraries
- Use UPX for compression

## Resources

- [PyInstaller Documentation](https://pyinstaller.org/)
- [GitHub Releases Guide](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Semantic Versioning](https://semver.org/)
