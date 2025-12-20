"""
Dice Dungeon Explorer - Simple GUI Installer
Copies pre-built EXE to chosen location and creates shortcuts
"""

import subprocess
import sys
import os
import platform
import shutil
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox

class SimpleInstallerGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Dice Dungeon Explorer - Installer")
        self.root.geometry("600x450")
        self.root.resizable(False, False)
        self.root.configure(bg='#2c1810')
        
        # Center window
        self.root.update_idletasks()
        x = (self.root.winfo_screenwidth() // 2) - (300)
        y = (self.root.winfo_screenheight() // 2) - (225)
        self.root.geometry(f'600x450+{x}+{y}')
        
        self.install_dir = None
        self.source_dir = os.path.dirname(os.path.abspath(__file__))
        
        # Check if EXE exists
        self.exe_source = os.path.join(self.source_dir, "dist", "DiceDungeon.exe")
        if not os.path.exists(self.exe_source):
            messagebox.showerror("Error", 
                "DiceDungeon.exe not found!\n\n"
                "The executable should be in the 'dist' folder.\n"
                "Please download the complete package from GitHub.")
            root.quit()
            return
        
        # Default installation path
        if platform.system() == "Windows":
            self.default_location = os.path.join(os.environ.get('PROGRAMFILES', 'C:\\Program Files'), 'Dice Dungeon')
        else:
            self.default_location = os.path.join(os.path.expanduser('~'), 'Games', 'DiceDungeon')
        
        self.create_welcome_screen()
    
    def create_welcome_screen(self):
        """Create the welcome screen"""
        # Title
        title = tk.Label(self.root, text="🎲 DICE DUNGEON EXPLORER", 
                        font=('Arial', 24, 'bold'), bg='#2c1810', fg='#ffd700')
        title.pack(pady=30)
        
        # Welcome message
        msg = tk.Label(self.root, 
                      text="Welcome to Dice Dungeon!\n\n"
                           "This installer will set up the game on your computer.\n\n"
                           "What will be installed:\n"
                           "• DiceDungeon.exe (game executable)\n"
                           "• Desktop shortcut\n"
                           "• Start Menu shortcut\n\n"
                           "Installation size: ~100 MB\n"
                           "Time required: ~10 seconds",
                      font=('Arial', 11), bg='#2c1810', fg='#ffffff',
                      justify='left')
        msg.pack(pady=20)
        
        # Continue button
        btn = tk.Button(self.root, text="Continue", 
                       font=('Arial', 14, 'bold'),
                       bg='#4ecdc4', fg='#000000',
                       command=self.choose_install_location,
                       padx=30, pady=10)
        btn.pack(pady=20)
        
        # Cancel button
        cancel = tk.Button(self.root, text="Cancel", 
                          font=('Arial', 10),
                          bg='#666666', fg='#ffffff',
                          command=self.root.quit,
                          padx=20, pady=5)
        cancel.pack(pady=5)
    
    def choose_install_location(self):
        """Let user choose installation directory"""
        self.clear_window()
        
        tk.Label(self.root, text="Choose Install Location", 
                font=('Arial', 20, 'bold'), bg='#2c1810', fg='#ffd700').pack(pady=30)
        
        tk.Label(self.root, 
                text="Where would you like to install Dice Dungeon?",
                font=('Arial', 12), bg='#2c1810', fg='#ffffff').pack(pady=10)
        
        # Location display
        loc_frame = tk.Frame(self.root, bg='#3d2415', relief=tk.SUNKEN, borderwidth=2)
        loc_frame.pack(pady=20, padx=40, fill='x')
        
        self.location_label = tk.Label(loc_frame, text=self.default_location,
                                      font=('Arial', 10), bg='#3d2415', fg='#ffffff',
                                      wraplength=500)
        self.location_label.pack(pady=10, padx=10)
        
        # Browse button
        tk.Button(self.root, text="Browse...", 
                 font=('Arial', 11),
                 bg='#4ecdc4', fg='#000000',
                 command=self.browse_location,
                 padx=30, pady=5).pack(pady=10)
        
        # Space info
        tk.Label(self.root, text="Installation size: ~100 MB",
                font=('Arial', 10), bg='#2c1810', fg='#cccccc').pack(pady=10)
        
        # Continue button
        btn_frame = tk.Frame(self.root, bg='#2c1810')
        btn_frame.pack(pady=30)
        
        tk.Button(btn_frame, text="Install", 
                 font=('Arial', 14, 'bold'),
                 bg='#4ecdc4', fg='#000000',
                 command=self.start_installation,
                 padx=40, pady=10).pack(side='left', padx=10)
        
        tk.Button(btn_frame, text="Back", 
                 font=('Arial', 12),
                 bg='#666666', fg='#ffffff',
                 command=self.create_welcome_screen,
                 padx=30, pady=10).pack(side='left', padx=10)
    
    def browse_location(self):
        """Open folder browser"""
        chosen_dir = filedialog.askdirectory(
            title="Choose Installation Folder",
            initialdir=os.path.dirname(self.default_location)
        )
        
        if chosen_dir:
            if not chosen_dir.endswith('Dice Dungeon'):
                chosen_dir = os.path.join(chosen_dir, 'Dice Dungeon')
            self.default_location = chosen_dir
            self.location_label.config(text=chosen_dir)
    
    def start_installation(self):
        """Begin the installation process"""
        self.install_dir = self.default_location
        
        self.clear_window()
        tk.Label(self.root, text="Installing...", 
                font=('Arial', 20, 'bold'), bg='#2c1810', fg='#ffd700').pack(pady=40)
        
        status = tk.Label(self.root, text="Copying files...",
                         font=('Arial', 12), bg='#2c1810', fg='#ffffff')
        status.pack(pady=20)
        
        self.root.update()
        
        try:
            # Create install directory
            os.makedirs(self.install_dir, exist_ok=True)
            
            # Copy EXE
            exe_dest = os.path.join(self.install_dir, "DiceDungeon.exe")
            shutil.copy2(self.exe_source, exe_dest)
            
            # Create saves folder
            saves_dir = os.path.join(self.install_dir, "saves")
            os.makedirs(saves_dir, exist_ok=True)
            
            # Copy documentation
            for doc in ["README.md", "CHANGELOG.md"]:
                src = os.path.join(self.source_dir, doc)
                if os.path.exists(src):
                    shutil.copy2(src, self.install_dir)
            
            status.config(text="Creating shortcuts...")
            self.root.update()
            
            # Create shortcuts
            self.create_shortcuts()
            
            # Create uninstaller
            self.create_uninstaller()
            
            # Done!
            self.show_completion()
        
        except Exception as e:
            messagebox.showerror("Installation Error", f"Installation failed: {e}")
            self.root.quit()
    
    def create_shortcuts(self):
        """Create desktop and start menu shortcuts"""
        if platform.system() != "Windows":
            return
        
        try:
            # Try to install pywin32 if not available
            try:
                import winshell
                from win32com.client import Dispatch
            except ImportError:
                subprocess.run([sys.executable, "-m", "pip", "install", "--quiet", "pywin32"], 
                              capture_output=True, timeout=30)
                import winshell
                from win32com.client import Dispatch
            
            exe_path = os.path.join(self.install_dir, "DiceDungeon.exe")
            shell = Dispatch('WScript.Shell')
            
            # Desktop shortcut
            try:
                desktop = winshell.desktop()
                shortcut_path = os.path.join(desktop, "Dice Dungeon.lnk")
                shortcut = shell.CreateShortCut(shortcut_path)
                shortcut.Targetpath = exe_path
                shortcut.WorkingDirectory = self.install_dir
                shortcut.Description = "Dice Dungeon Explorer"
                shortcut.save()
            except:
                pass
            
            # Start menu
            try:
                start_menu = winshell.start_menu()
                programs = os.path.join(start_menu, "Programs", "Dice Dungeon")
                os.makedirs(programs, exist_ok=True)
                
                start_shortcut_path = os.path.join(programs, "Dice Dungeon.lnk")
                shortcut = shell.CreateShortCut(start_shortcut_path)
                shortcut.Targetpath = exe_path
                shortcut.WorkingDirectory = self.install_dir
                shortcut.Description = "Dice Dungeon Explorer"
                shortcut.save()
            except:
                pass
        
        except:
            # If shortcuts fail, that's okay - user can still run the EXE directly
            pass
    
    def create_uninstaller(self):
        """Create uninstaller script"""
        if platform.system() == "Windows":
            uninstall_content = f'''@echo off
echo.
echo Dice Dungeon Explorer - Uninstaller
echo.
echo This will remove Dice Dungeon from your computer.
echo Your save files will be preserved unless you delete them manually.
echo.
pause

echo.
echo Removing shortcuts...
del "%USERPROFILE%\\Desktop\\Dice Dungeon.lnk" 2>nul
rmdir /s /q "%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Dice Dungeon" 2>nul

echo.
echo Uninstall complete. To finish, delete this folder:
echo {self.install_dir}
echo.
pause
'''
            uninstall_path = os.path.join(self.install_dir, "Uninstall.bat")
            with open(uninstall_path, 'w') as f:
                f.write(uninstall_content)
    
    def show_completion(self):
        """Show installation complete screen"""
        self.clear_window()
        
        tk.Label(self.root, text="✓ Installation Complete!", 
                font=('Arial', 24, 'bold'), bg='#2c1810', fg='#4ecdc4').pack(pady=40)
        
        info_text = f"""Dice Dungeon has been successfully installed!

Installed to:
{self.install_dir}

You can now:
• Double-click 'Dice Dungeon' on your Desktop
• Find it in your Start Menu
• Run DiceDungeon.exe from the install folder

The downloaded folder can be safely deleted:
{self.source_dir}

Enjoy the game! 🎲"""
        
        tk.Label(self.root, text=info_text,
                font=('Arial', 11), bg='#2c1810', fg='#ffffff',
                justify='left').pack(pady=20)
        
        btn_frame = tk.Frame(self.root, bg='#2c1810')
        btn_frame.pack(pady=20)
        
        tk.Button(btn_frame, text="Launch Game", 
                 font=('Arial', 12, 'bold'),
                 bg='#4ecdc4', fg='#000000',
                 command=self.launch_game,
                 padx=30, pady=10).pack(side='left', padx=10)
        
        tk.Button(btn_frame, text="Close", 
                 font=('Arial', 12),
                 bg='#666666', fg='#ffffff',
                 command=self.root.quit,
                 padx=30, pady=10).pack(side='left', padx=10)
    
    def launch_game(self):
        """Launch the installed game"""
        exe_path = os.path.join(self.install_dir, "DiceDungeon.exe")
        if os.path.exists(exe_path):
            subprocess.Popen([exe_path], cwd=self.install_dir)
        self.root.quit()
    
    def clear_window(self):
        """Clear all widgets from window"""
        for widget in self.root.winfo_children():
            widget.destroy()

def main():
    """Main entry point"""
    root = tk.Tk()
    app = SimpleInstallerGUI(root)
    root.mainloop()

if __name__ == "__main__":
    main()
