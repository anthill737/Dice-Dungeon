"""
UI Dialogs Manager for Dice Dungeon Explorer
Handles settings menu, high scores, and other UI dialogs
"""

import tkinter as tk
from tkinter import messagebox
import json
import os


class UIDialogsManager:
    """Manages UI dialogs like settings and high scores"""
    
    def __init__(self, game):
        self.game = game
    
    def show_high_scores(self):
        """Show high scores"""
        if not os.path.exists(self.game.scores_file):
            messagebox.showinfo("High Scores", "No high scores yet!")
            return
        
        try:
            with open(self.game.scores_file, 'r') as f:
                scores = json.load(f)
        except:
            messagebox.showinfo("High Scores", "No high scores yet!")
            return
        
        # Close existing dialog if any
        if hasattr(self.game, 'dialog_frame') and self.game.dialog_frame and self.game.dialog_frame.winfo_exists():
            self.game.dialog_frame.destroy()
            self.game.dialog_frame = None
        
        # Create dialog
        dialog_width, dialog_height = self.game.get_responsive_dialog_size(800, 650, 0.8, 0.85)
        
        # Determine parent: use game_frame if in-game, otherwise use root (for main menu)
        parent = self.game.root
        if hasattr(self.game, 'game_frame') and self.game.game_frame is not None and self.game.game_frame.winfo_exists():
            parent = self.game.game_frame
        
        self.game.dialog_frame = tk.Frame(parent, bg=self.game.current_colors["bg_primary"], 
                                      relief=tk.RIDGE, borderwidth=3)
        self.game.dialog_frame.place(relx=0.5, rely=0.5, anchor='center', 
                                width=dialog_width, height=dialog_height)
        
        # Red X close button (top right corner)
        close_btn = tk.Label(self.game.dialog_frame, text="✕", font=('Arial', 16, 'bold'),
                            bg=self.game.current_colors["bg_primary"], fg='#ff4444', cursor="hand2", padx=5)
        close_btn.place(relx=0.98, rely=0.02, anchor='ne')
        close_btn.bind('<Button-1>', lambda e: self.game.close_dialog())
        close_btn.bind('<Enter>', lambda e: close_btn.config(fg='#ff0000'))
        close_btn.bind('<Leave>', lambda e: close_btn.config(fg='#ff4444'))
        
        # Title
        tk.Label(self.game.dialog_frame, text="🏆 HIGH SCORES 🏆",
                font=('Arial', 20, 'bold'),
                bg=self.game.current_colors["bg_primary"],
                fg=self.game.current_colors["text_gold"],
                pady=15).pack()
        
        # Create scrollable content
        canvas = tk.Canvas(self.game.dialog_frame, bg=self.game.current_colors["bg_secondary"], highlightthickness=0)
        scrollbar = tk.Scrollbar(self.game.dialog_frame, orient="vertical", command=canvas.yview, width=10,
                                bg=self.game.current_colors["bg_secondary"], troughcolor=self.game.current_colors["bg_dark"])
        content_frame = tk.Frame(canvas, bg=self.game.current_colors["bg_secondary"])
        
        content_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=content_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        
        canvas.pack(side="left", fill="both", expand=True, padx=15, pady=10)
        scrollbar.pack(side="right", fill="y", pady=10)
        
        # Display scores
        for i, score in enumerate(scores, 1):
            score_frame = tk.Frame(content_frame, bg=self.game.current_colors["bg_panel"], 
                                  relief=tk.RAISED, borderwidth=2)
            score_frame.pack(fill=tk.X, padx=10, pady=5)
            
            # Main content frame (horizontal layout)
            content = tk.Frame(score_frame, bg=self.game.current_colors["bg_panel"])
            content.pack(fill=tk.X, padx=10, pady=8)
            
            # Rank (1st, 2nd, etc.)
            rank_colors = {1: '#ffd700', 2: '#c0c0c0', 3: '#cd7f32'}
            rank_color = rank_colors.get(i, self.game.current_colors["text_secondary"])
            tk.Label(content, text=f"#{i}", font=('Arial', 14, 'bold'),
                    bg=self.game.current_colors["bg_panel"], fg=rank_color,
                    width=3).grid(row=0, column=0, sticky='w', padx=(0, 10))
            
            # Score
            tk.Label(content, text=f"{score['score']:,} pts", font=('Arial', 13, 'bold'),
                    bg=self.game.current_colors["bg_panel"], fg=self.game.current_colors["text_gold"],
                    width=12, anchor='w').grid(row=0, column=1, sticky='w', padx=5)
            
            # Floor
            tk.Label(content, text=f"Floor {score['floor']}", font=('Arial', 11),
                    bg=self.game.current_colors["bg_panel"], fg=self.game.current_colors["text_cyan"],
                    width=10, anchor='w').grid(row=0, column=2, sticky='w', padx=5)
            
            # Rooms
            tk.Label(content, text=f"{score['rooms']} rooms", font=('Arial', 11),
                    bg=self.game.current_colors["bg_panel"], fg=self.game.current_colors["text_secondary"],
                    width=10, anchor='w').grid(row=0, column=3, sticky='w', padx=5)
            
            # Gold
            tk.Label(content, text=f"{score['gold']}g", font=('Arial', 11),
                    bg=self.game.current_colors["bg_panel"], fg=self.game.current_colors["text_secondary"],
                    width=10, anchor='w').grid(row=0, column=4, sticky='w', padx=5)
            
            # Kills
            tk.Label(content, text=f"{score['kills']} kills", font=('Arial', 11),
                    bg=self.game.current_colors["bg_panel"], fg=self.game.current_colors["text_secondary"],
                    width=10, anchor='w').grid(row=0, column=5, sticky='w', padx=5)
            
            # Stats button
            if 'stats' in score:
                tk.Button(content, text="Stats",
                         command=lambda s=score: self.game.show_stats(s.get('stats', {}), self.show_high_scores),
                         font=('Arial', 9, 'bold'), bg=self.game.current_colors["button_primary"], 
                         fg='#000000', width=8, pady=3).grid(row=0, column=6, padx=10)
        
        # Setup mousewheel scrolling AFTER all widgets are added
        self.game.setup_mousewheel_scrolling(canvas)
    
    def show_settings(self, return_to=None):
        """Show settings dialog - delegates to main file for now due to complexity"""
        # Call the main file's implementation
        # This is a temporary delegation until the full settings UI is refactored
        self.game._show_settings_implementation(return_to)
