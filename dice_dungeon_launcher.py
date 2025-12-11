"""
Dice Dungeon RPG - Game Launcher
Choose between Classic mode or Explorer mode
"""

import tkinter as tk
import subprocess
import os

class GameLauncher:
    def __init__(self, root):
        self.root = root
        self.root.title("Dice Dungeon RPG - Launcher")
        self.root.geometry("600x500")
        self.root.configure(bg='#2c1810')
        self.root.resizable(False, False)
        
        # Center window
        self.root.update_idletasks()
        x = (self.root.winfo_screenwidth() // 2) - (600 // 2)
        y = (self.root.winfo_screenheight() // 2) - (500 // 2)
        self.root.geometry(f'600x500+{x}+{y}')
        
        self.setup_ui()
    
    def setup_ui(self):
        # Title
        tk.Label(self.root, text="DICE DUNGEON RPG", 
                font=('Arial', 28, 'bold'), bg='#2c1810', fg='#ffd700',
                pady=30).pack()
        
        tk.Label(self.root, text="Choose Your Adventure", 
                font=('Arial', 16), bg='#2c1810', fg='#ffffff',
                pady=10).pack()
        
        # Game mode cards
        cards_frame = tk.Frame(self.root, bg='#2c1810')
        cards_frame.pack(pady=30)
        
        # Classic Mode Card
        classic_card = tk.Frame(cards_frame, bg='#3d2415', relief=tk.RAISED, borderwidth=3)
        classic_card.pack(side=tk.LEFT, padx=20)
        
        tk.Label(classic_card, text="⚔️ CLASSIC MODE ⚔️", 
                font=('Arial', 16, 'bold'), bg='#3d2415', fg='#4ecdc4',
                pady=15).pack()
        
        classic_desc = """
Fight your way through floors
        
• Floor-by-floor progression
• Boss battles
• Shop upgrades
• Fast-paced action
• Dice combat system
        """
        
        tk.Label(classic_card, text=classic_desc, 
                font=('Arial', 10), bg='#3d2415', fg='#ffffff',
                justify=tk.LEFT, padx=20, pady=10).pack()
        
        tk.Button(classic_card, text="PLAY CLASSIC", 
                 command=self.launch_classic,
                 font=('Arial', 12, 'bold'), bg='#4ecdc4', fg='#000000',
                 width=18, pady=12).pack(pady=15)
        
        # Explorer Mode Card
        explorer_card = tk.Frame(cards_frame, bg='#3d2415', relief=tk.RAISED, borderwidth=3)
        explorer_card.pack(side=tk.LEFT, padx=20)
        
        tk.Label(explorer_card, text="🗺️ EXPLORER MODE 🗺️", 
                font=('Arial', 16, 'bold'), bg='#3d2415', fg='#ffd700',
                pady=15).pack()
        
        explorer_desc = """
Explore procedural dungeons
        
• Roguelike exploration
• 100+ unique rooms
• Dynamic dungeon map
• Discover secrets
• Betrayal-style tiles
        """
        
        tk.Label(explorer_card, text=explorer_desc, 
                font=('Arial', 10), bg='#3d2415', fg='#ffffff',
                justify=tk.LEFT, padx=20, pady=10).pack()
        
        tk.Button(explorer_card, text="PLAY EXPLORER", 
                 command=self.launch_explorer,
                 font=('Arial', 12, 'bold'), bg='#ffd700', fg='#000000',
                 width=18, pady=12).pack(pady=15)
        
        # Quit button
        tk.Button(self.root, text="QUIT", 
                 command=self.root.quit,
                 font=('Arial', 11, 'bold'), bg='#ff6b6b', fg='#000000',
                 width=15, pady=10).pack(pady=20)
    
    def launch_classic(self):
        """Launch the classic mode game"""
        script_dir = os.path.dirname(__file__)
        classic_path = os.path.join(script_dir, 'dice_dungeon_rpg.py')
        
        try:
            subprocess.Popen(['python', classic_path])
            self.root.quit()
        except Exception as e:
            tk.messagebox.showerror("Error", f"Could not launch Classic Mode:\n{e}")
    
    def launch_explorer(self):
        """Launch the explorer mode game"""
        script_dir = os.path.dirname(__file__)
        explorer_path = os.path.join(script_dir, 'dice_dungeon_explorer.py')
        
        try:
            subprocess.Popen(['python', explorer_path])
            self.root.quit()
        except Exception as e:
            tk.messagebox.showerror("Error", f"Could not launch Explorer Mode:\n{e}")

if __name__ == "__main__":
    root = tk.Tk()
    app = GameLauncher(root)
    root.mainloop()
