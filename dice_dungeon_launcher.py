"""
Dice Dungeon RPG - Game Launcher
Choose between Classic mode or Explorer mode
"""

import tkinter as tk
import sys
import os

def get_resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)

class GameLauncher:
    def __init__(self, root):
        self.root = root
        self.scale_factor = 1.0  # Launcher uses fixed size, but fonts go through scale_font for consistency
        self.root.title("Dice Dungeon - Launcher")
        self.root.configure(bg='#2c1810')  # Set background immediately to prevent white flash
        self.root.geometry("600x600")  # Increased height to fit logo
        self.root.resizable(False, False)
        
        # Withdraw window until it's fully built to prevent flash
        self.root.withdraw()
        
        # Set DD Icon for the window
        try:
            icon_path = get_resource_path(os.path.join("assets", "DD Icon.png"))
            if os.path.exists(icon_path):
                from PIL import Image, ImageTk
                icon_img = Image.open(icon_path)
                icon_photo = ImageTk.PhotoImage(icon_img)
                self.root.iconphoto(True, icon_photo)
        except:
            pass  # Use default icon if loading fails
        
        self.setup_ui()
        
        # Center window after UI is built
        self.root.update_idletasks()
        x = (self.root.winfo_screenwidth() // 2) - (600 // 2)
        y = (self.root.winfo_screenheight() // 2) - (600 // 2)
        self.root.geometry(f'600x600+{x}+{y}')
        
        # Show window now that it's ready
        self.root.deiconify()
    
    def scale_font(self, base_size):
        """Scale font size consistently with the main game's approach"""
        return max(8, int(base_size * self.scale_factor * 1.15))
    
    def setup_ui(self):
        # Logo
        try:
            logo_path = get_resource_path(os.path.join("assets", "DD Logo.png"))
            if os.path.exists(logo_path):
                from PIL import Image, ImageTk
                img = Image.open(logo_path)
                img = img.resize((120, 120), Image.LANCZOS)
                self.logo_image = ImageTk.PhotoImage(img)
                
                logo_label = tk.Label(self.root, image=self.logo_image, bg='#2c1810')
                logo_label.pack(pady=(20, 5))
        except:
            pass  # Skip logo if loading fails
        
        # Title
        tk.Label(self.root, text="DICE DUNGEON", 
                font=('Arial', self.scale_font(28), 'bold'), bg='#2c1810', fg='#ffd700',
                pady=10).pack()
        
        tk.Label(self.root, text="Choose Your Game Mode", 
                font=('Arial', self.scale_font(16)), bg='#2c1810', fg='#ffffff',
                pady=10).pack()
        
        # Game mode cards
        cards_frame = tk.Frame(self.root, bg='#2c1810')
        cards_frame.pack(pady=20)
        
        # Classic Mode Card
        classic_card = tk.Frame(cards_frame, bg='#3d2415', relief=tk.RAISED, borderwidth=3)
        classic_card.pack(side=tk.LEFT, padx=15)
        
        tk.Label(classic_card, text="⚔️ CLASSIC ⚔️", 
                font=('Arial', self.scale_font(14), 'bold'), bg='#3d2415', fg='#4ecdc4',
                pady=10).pack()
        
        classic_desc = """Floor-by-floor • Boss battles
Shop upgrades • Fast action"""
        
        tk.Label(classic_card, text=classic_desc, 
                font=('Arial', self.scale_font(9)), bg='#3d2415', fg='#ffffff',
                justify=tk.CENTER, padx=15, pady=8).pack()
        
        tk.Button(classic_card, text="PLAY CLASSIC", 
                 command=self.launch_classic,
                 font=('Arial', self.scale_font(11), 'bold'), bg='#4ecdc4', fg='#000000',
                 width=16, pady=10).pack(pady=12)
        
        # Adventure Mode Card
        adventure_card = tk.Frame(cards_frame, bg='#3d2415', relief=tk.RAISED, borderwidth=3)
        adventure_card.pack(side=tk.LEFT, padx=15)
        
        tk.Label(adventure_card, text="🗺  ADVENTURE  🗺", 
                font=('Arial', self.scale_font(14), 'bold'), bg='#3d2415', fg='#ffd700',
                pady=10).pack()
        
        adventure_desc = """Procedural dungeons • 100+ rooms
Dynamic map • Mysterious lore"""
        
        tk.Label(adventure_card, text=adventure_desc, 
                font=('Arial', self.scale_font(9)), bg='#3d2415', fg='#ffffff',
                justify=tk.CENTER, padx=15, pady=8).pack()
        
        tk.Button(adventure_card, text="PLAY ADVENTURE", 
                 command=self.launch_explorer,
                 font=('Arial', self.scale_font(11), 'bold'), bg='#ffd700', fg='#000000',
                 width=16, pady=10).pack(pady=12)
        
        # Quit button
        tk.Button(self.root, text="QUIT", 
                 command=self.quit_launcher,
                 font=('Arial', self.scale_font(11), 'bold'), bg='#ff6b6b', fg='#000000',
                 width=15, pady=8).pack(pady=15)
    
    def quit_launcher(self):
        """Properly quit the launcher application"""
        self.root.quit()
        self.root.destroy()
        sys.exit(0)
    
    def launch_classic(self):
        """Launch the classic mode game"""
        try:
            self.root.destroy()  # Close launcher
            self.show_splash_classic()
        except Exception as e:
            import tkinter.messagebox as messagebox
            messagebox.showerror("Error", f"Could not launch Classic Mode:\n{e}")
    
    def launch_explorer(self):
        """Launch the explorer mode game"""
        try:
            self.root.destroy()  # Close launcher
            self.show_splash_explorer()
        except Exception as e:
            import tkinter.messagebox as messagebox
            messagebox.showerror("Error", f"Could not launch Explorer Mode:\n{e}")
    
    def show_splash_classic(self):
        """Show splash screen for Classic Mode"""
        splash = tk.Tk()
        splash.title("Dice Dungeon Classic")
        splash.resizable(False, False)
        splash.configure(bg='#2c1810')
        
        width = 650
        height = 450
        x = (splash.winfo_screenwidth() // 2) - (width // 2)
        y = (splash.winfo_screenheight() // 2) - (height // 2)
        splash.geometry(f'{width}x{height}+{x}+{y}')
        splash.overrideredirect(True)
        
        main_frame = tk.Frame(splash, bg='#2c1810', relief=tk.RAISED, borderwidth=3)
        main_frame.pack(fill=tk.BOTH, expand=True, padx=8, pady=8)
        
        # Logo
        logo_image = None
        try:
            logo_path = get_resource_path(os.path.join("assets", "DD Logo.png"))
            if os.path.exists(logo_path):
                from PIL import Image, ImageTk
                img = Image.open(logo_path)
                img = img.resize((120, 120), Image.LANCZOS)
                logo_image = ImageTk.PhotoImage(img)
                logo_label = tk.Label(main_frame, image=logo_image, bg='#2c1810')
                logo_label.image = logo_image
                logo_label.pack(pady=(30, 15))
        except:
            pass
        
        tk.Label(main_frame, text="DICE DUNGEON CLASSIC",
                font=('Arial', self.scale_font(22), 'bold'), bg='#2c1810', fg='#ffd700').pack(pady=8)
        tk.Label(main_frame, text="Roll • Fight • Survive",
                font=('Arial', self.scale_font(12), 'italic'), bg='#2c1810', fg='#ffffff').pack(pady=5)
        
        # Loading area
        loading_frame = tk.Frame(main_frame, bg='#2c1810')
        loading_frame.pack(pady=(30, 30), expand=True)
        
        text_frame = tk.Frame(loading_frame, bg='#2c1810')
        text_frame.pack()
        
        loading_label = tk.Label(text_frame, text="Loading game engine",
                               font=('Arial', self.scale_font(14)), bg='#2c1810', fg='#ffffff')
        loading_label.pack(side=tk.LEFT)
        
        dots_label = tk.Label(text_frame, text="",
                            font=('Arial', self.scale_font(14)), bg='#2c1810', fg='#ffd700')
        dots_label.pack(side=tk.LEFT)
        
        # Progress tracking
        progress = [0]
        max_progress = 25
        loading_messages = [
            "Loading game engine",
            "Loading dice mechanics",
            "Loading enemy data",
            "Loading shop items",
            "Preparing combat system",
            "Starting game"
        ]
        message_index = [0]
        
        def animate():
            if progress[0] < max_progress:
                # Update dots
                dots = "." * ((progress[0] % 3) + 1)
                dots_label.config(text=dots)
                
                # Update loading message
                message_interval = max(1, max_progress // len(loading_messages))
                if progress[0] % message_interval == 0 and message_index[0] < len(loading_messages):
                    loading_label.config(text=loading_messages[message_index[0]])
                    message_index[0] += 1
                
                progress[0] += 1
                splash.after(200, animate)
            else:
                # Loading complete - launch immediately
                launch_game()
        
        def launch_game():
            splash.destroy()
            try:
                import dice_dungeon_rpg
                root = tk.Tk()
                app = dice_dungeon_rpg.DiceDungeonRPG(root)
                root.mainloop()
            except Exception as e:
                import traceback
                err_root = tk.Tk()
                err_root.withdraw()
                import tkinter.messagebox as mb
                mb.showerror("Launch Error", 
                    f"Could not launch Classic Mode:\n\n{e}\n\n{traceback.format_exc()}",
                    parent=err_root)
                err_root.destroy()
        
        animate()
        splash.mainloop()
    
    def show_splash_explorer(self):
        """Show splash screen for Explorer Mode with real progress tracking"""
        import time
        
        # Create the real root first (will become the game window)
        game_root = tk.Tk()
        game_root.withdraw()  # Hide until loading is done
        
        # Create splash as a Toplevel so destroying it doesn't kill the app
        splash = tk.Toplevel(game_root)
        splash.title("Dice Dungeon")
        splash.resizable(False, False)
        splash.configure(bg='#0a0604')
        
        width = 650
        height = 450
        x = (splash.winfo_screenwidth() // 2) - (width // 2)
        y = (splash.winfo_screenheight() // 2) - (height // 2)
        splash.geometry(f'{width}x{height}+{x}+{y}')
        splash.overrideredirect(True)
        
        try:
            icon_path = get_resource_path(os.path.join("assets", "DD Logo.png"))
            if os.path.exists(icon_path):
                icon = tk.PhotoImage(file=icon_path, master=splash)
                splash.iconphoto(True, icon)
        except:
            pass
        
        main_frame = tk.Frame(splash, bg='#0a0604', relief=tk.RAISED, borderwidth=3)
        main_frame.pack(fill=tk.BOTH, expand=True, padx=8, pady=8)
        
        # Logo
        logo_image_ref = None
        try:
            logo_path = get_resource_path(os.path.join("assets", "DD Logo.png"))
            if os.path.exists(logo_path):
                from PIL import Image, ImageTk
                img = Image.open(logo_path)
                img = img.resize((120, 120), Image.LANCZOS)
                logo_image_ref = ImageTk.PhotoImage(img, master=splash)
                logo_label = tk.Label(main_frame, image=logo_image_ref, bg='#0a0604')
                logo_label.pack(pady=(30, 15))
            else:
                tk.Label(main_frame, text="DD", font=('Arial', self.scale_font(42), 'bold'),
                        bg='#0a0604', fg='#d4af37').pack(pady=(40, 15))
        except Exception:
            tk.Label(main_frame, text="DD", font=('Arial', self.scale_font(42), 'bold'),
                    bg='#0a0604', fg='#d4af37').pack(pady=(40, 15))
        
        tk.Label(main_frame, text="DICE DUNGEON",
                font=('Arial', self.scale_font(22), 'bold'), bg='#0a0604', fg='#d4af37').pack(pady=8)
        tk.Label(main_frame, text="Explore \u2022 Fight \u2022 Loot \u2022 Survive",
                font=('Arial', self.scale_font(12), 'italic'), bg='#0a0604', fg='#8b7355').pack(pady=5)
        
        loading_frame = tk.Frame(main_frame, bg='#0a0604')
        loading_frame.pack(pady=(30, 30), fill=tk.X, expand=True)
        
        loading_label = tk.Label(loading_frame, text="Initializing...",
                                font=('Arial', self.scale_font(14)), bg='#0a0604', fg='#e8dcc4',
                                anchor='center')
        loading_label.pack(expand=True)
        
        # State for dot animation
        _current_message = ['']
        _dot_after_id = [None]
        _dot_phase = [0]
        
        def _start_dot_cycle():
            """Keep cycling .  ..  ... on the current message until the next update."""
            if not (splash and splash.winfo_exists()):
                return
            _dot_phase[0] = (_dot_phase[0] % 3) + 1
            dots = "." * _dot_phase[0]
            loading_label.config(text=f"{_current_message[0]}{dots}")
            splash.update_idletasks()
            _dot_after_id[0] = splash.after(220, _start_dot_cycle)
        
        def update_status(message):
            """Update the splash loading text with animated dots."""
            if not (splash and splash.winfo_exists()):
                return
            clean = message.rstrip('. ')
            if clean == _current_message[0]:
                splash.update()
                return
            _current_message[0] = clean
            if _dot_after_id[0]:
                splash.after_cancel(_dot_after_id[0])
                _dot_after_id[0] = None
            for dot_count in range(1, 4):
                dots = "." * dot_count
                loading_label.config(text=f"{clean}{dots}")
                splash.update()
                time.sleep(0.18)
            _dot_phase[0] = 0
            _start_dot_cycle()
        
        def show_instant(message):
            """Flash a message without slow dot animation."""
            if splash and splash.winfo_exists():
                if _dot_after_id[0]:
                    splash.after_cancel(_dot_after_id[0])
                    _dot_after_id[0] = None
                clean = message.rstrip('. ')
                _current_message[0] = clean
                loading_label.config(text=f"{clean}...")
                splash.update()
        
        # Make splash visible before starting to load
        splash.update()
        
        def do_load():
            """Load the game on the main thread, updating splash as we go."""
            try:
                import dice_dungeon_explorer
                app = dice_dungeon_explorer.DiceDungeonExplorer(
                    game_root,
                    progress_callback=update_status
                )
            except Exception as e:
                import traceback
                update_status(f"Error: {e}")
                splash.after(3000, splash.destroy)
                return
            
            # Loading complete - show final messages, then transition
            show_instant("Starting adventure...")
            show_instant("Ready!")
            
            # Cancel dot animation loop
            if _dot_after_id[0]:
                try:
                    splash.after_cancel(_dot_after_id[0])
                except Exception:
                    pass
                _dot_after_id[0] = None
            
            # Make game window fully transparent, then deiconify so geometry works
            game_root.attributes('-alpha', 0.0)
            game_root.deiconify()
            game_root.update_idletasks()
            # Clear the progress callback so apply_resolution's sprite rebuild
            # doesn't re-trigger the splash animation
            app._progress_callback = None
            # Apply saved resolution
            saved_res = app.settings.get("resolution", "950x700")
            app.apply_resolution(saved_res, save=False)
            # Build the main menu with correct window dimensions
            app.main_menu_manager.show_main_menu()
            game_root.update_idletasks()
            # Destroy splash and reveal the fully-built game window
            if splash and splash.winfo_exists():
                splash.destroy()
            game_root.attributes('-alpha', 1.0)
        
        splash.after(200, do_load)
        game_root.mainloop()

if __name__ == "__main__":
    root = tk.Tk()
    app = GameLauncher(root)
    root.mainloop()
