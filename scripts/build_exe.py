"""
Build Script - Creates a standalone executable for Dice Dungeon
Requires PyInstaller: pip install pyinstaller
"""

import subprocess
import sys
import os
import shutil
from pathlib import Path

def print_header(text):
    print("\n" + "=" * 60)
    print(f"  {text}")
    print("=" * 60 + "\n")

def check_pyinstaller():
    """Check if PyInstaller is installed"""
    try:
        import PyInstaller
        print("✓ PyInstaller is installed")
        return True
    except ImportError:
        print("❌ PyInstaller not found")
        print("\nInstalling PyInstaller...")
        try:
            subprocess.run([sys.executable, "-m", "pip", "install", "pyinstaller"],
                          check=True)
            print("✓ PyInstaller installed successfully")
            return True
        except subprocess.CalledProcessError:
            print("❌ Failed to install PyInstaller")
            return False

def build_executable():
    """Build the standalone executable"""
    print_header("Building Executable")
    
    # Check for DD Icon and convert to .ico if needed
    icon_png = "assets/DD Icon.png"
    icon_ico = "assets/DD Icon.ico"
    
    if os.path.exists(icon_png) and not os.path.exists(icon_ico):
        try:
            from PIL import Image
            print("Converting DD Icon.png to .ico format...")
            img = Image.open(icon_png)
            img.save(icon_ico, format='ICO', sizes=[(256, 256)])
            print("✓ Icon converted successfully")
        except Exception as e:
            print(f"⚠ Could not convert icon: {e}")
            icon_ico = None
    elif os.path.exists(icon_ico):
        print("✓ Using DD Icon.ico")
    else:
        print("⚠ No DD Icon found, using default icon")
        icon_ico = None
    
    # PyInstaller command
    cmd = [
        sys.executable, "-m", "PyInstaller",
        "--name=DiceDungeon",
        "--onefile",
        "--windowed",  # No console window
        "--add-data=assets;assets",
        "--add-data=dice_dungeon_content;dice_dungeon_content",
        "--add-data=explorer;explorer",
        "--add-data=saves;saves",
        "--hidden-import=dice_dungeon_rpg",  # Include classic mode
        "--hidden-import=dice_dungeon_explorer",  # Include explorer mode
        "--noconsole",
    ]
    
    # Add icon if available
    if icon_ico and os.path.exists(icon_ico):
        cmd.append(f"--icon={icon_ico}")
    
    cmd.append("dice_dungeon_launcher.py")
    
    print("Running PyInstaller...")
    print(f"Command: {' '.join(cmd)}\n")
    
    try:
        subprocess.run(cmd, check=True)
        print("\n✓ Executable built successfully!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Build failed: {e}")
        return False

def create_distribution():
    """Create a distribution folder with the exe and necessary files"""
    print_header("Creating Distribution Package")
    
    dist_folder = Path("DiceDungeon_Portable")
    
    # Create fresh dist folder
    if dist_folder.exists():
        shutil.rmtree(dist_folder)
    dist_folder.mkdir()
    
    # Copy executable
    exe_path = Path("dist/DiceDungeon.exe")
    if exe_path.exists():
        shutil.copy(exe_path, dist_folder / "DiceDungeon.exe")
        print(f"✓ Copied executable")
    else:
        print("❌ Executable not found in dist/")
        return False
    
    # Copy essential folders
    folders_to_copy = ["assets", "saves"]
    for folder in folders_to_copy:
        if os.path.exists(folder):
            shutil.copytree(folder, dist_folder / folder)
            print(f"✓ Copied {folder}/")
    
    # Copy documentation
    docs_to_copy = ["README.md", "CHANGELOG.md", "LICENSE"]
    for doc in docs_to_copy:
        if os.path.exists(doc):
            shutil.copy(doc, dist_folder / doc)
            print(f"✓ Copied {doc}")
    
    # Create README for the distribution
    with open(dist_folder / "HOW_TO_PLAY.txt", 'w') as f:
        f.write("""
DICE DUNGEON - Portable Version

HOW TO PLAY:
1. Double-click DiceDungeon.exe
2. Choose your game mode (Classic or Explorer)
3. Use arrow keys to navigate
4. Press Space/Enter to confirm actions
5. Press ESC to open the menu

CONTROLS:
- Arrow Keys: Navigate
- Space/Enter: Confirm, roll dice
- R: Re-roll dice
- L: Lock/unlock dice
- A: Attack
- I: Inventory
- ESC: Menu

SAVES:
Your game saves are stored in the "saves" folder.
You can backup this folder to preserve your progress.

For full documentation, see README.md

Enjoy the adventure!
""")
    print("✓ Created HOW_TO_PLAY.txt")
    
    print(f"\n✓ Distribution package created: {dist_folder}/")
    return True

def create_installer():
    """Provide instructions for creating an installer with Inno Setup"""
    print_header("Installer Creation (Optional)")
    
    print("To create a Windows installer, you can use Inno Setup:")
    print("1. Download Inno Setup: https://jrsoftware.org/isdl.php")
    print("2. Use the provided installer script (if created)")
    print("3. Or use the portable folder for a no-install version")
    
    # Create an Inno Setup script
    iss_content = '''
[Setup]
AppName=Dice Dungeon
AppVersion=1.0
DefaultDirName={autopf}\\Dice Dungeon
DefaultGroupName=Dice Dungeon
OutputDir=installer_output
OutputBaseFilename=DiceDungeon_Setup
Compression=lzma2
SolidCompression=yes

[Files]
Source: "DiceDungeon_Portable\\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\\Dice Dungeon"; Filename: "{app}\\DiceDungeon.exe"
Name: "{commondesktop}\\Dice Dungeon"; Filename: "{app}\\DiceDungeon.exe"

[Run]
Filename: "{app}\\DiceDungeon.exe"; Description: "Launch Dice Dungeon"; Flags: nowait postinstall skipifsilent
'''
    
    with open("scripts/installer_script.iss", 'w') as f:
        f.write(iss_content)
    
    print("\n✓ Created scripts/installer_script.iss for Inno Setup")

def main():
    print("\n")
    print("╔═══════════════════════════════════════════════════════════╗")
    print("║                                                           ║")
    print("║        DICE DUNGEON - EXE BUILD WIZARD                    ║")
    print("║                                                           ║")
    print("╚═══════════════════════════════════════════════════════════╝")
    
    print("\nThis will create a standalone executable (.exe) that can run")
    print("on any Windows computer without requiring Python installation.\n")
    
    # Check PyInstaller
    if not check_pyinstaller():
        input("\nPress Enter to exit...")
        return 1
    
    # Build the executable
    if not build_executable():
        input("\nPress Enter to exit...")
        return 1
    
    # Create distribution package
    if not create_distribution():
        print("\n⚠ Warning: Distribution package creation failed")
    
    # Provide installer info
    create_installer()
    
    # Success!
    print_header("Build Complete!")
    print("✓ Standalone executable created")
    print("✓ Portable distribution package ready")
    print("\n📁 Files created:")
    print("   - dist/DiceDungeon.exe (raw executable)")
    print("   - DiceDungeon_Portable/ (complete portable package)")
    print("   - installer_script.iss (for creating Windows installer)")
    
    print("\n📝 Distribution Options:")
    print("   1. Share the DiceDungeon_Portable folder (no installation needed)")
    print("   2. Create an installer using Inno Setup + installer_script.iss")
    print("   3. Upload to GitHub releases as a .zip file")
    
    print("\n🎮 The executable is now ready to distribute!")
    input("\nPress Enter to exit...")
    return 0

if __name__ == "__main__":
    try:
        exit_code = main()
        sys.exit(exit_code)
    except KeyboardInterrupt:
        print("\n\nBuild cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        input("\nPress Enter to exit...")
        sys.exit(1)
