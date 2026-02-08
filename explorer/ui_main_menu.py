"""
Main Menu UI Manager

This module handles all main menu functionality including layout,
responsive design, and user interactions.
"""

import tkinter as tk
import os
from PIL import Image, ImageTk
from explorer.path_utils import get_asset_path


class MainMenuManager:
    """Manages the main menu interface and layout"""
    
    def __init__(self, game):
        self.game = game
        
    def show_main_menu(self):
        """Show the main menu with responsive layout that fills the screen"""
        if not self.game.content_loaded:
            return
        
        # Force window update to get accurate dimensions
        self.game.root.update_idletasks()
        
        # Calculate initial scale factor based on current window size
        current_width = self.game.root.winfo_width()
        current_height = self.game.root.winfo_height()
        if current_width > 1 and current_height > 1:  # Window has been sized
            width_scale = current_width / self.game.base_window_width
            height_scale = current_height / self.game.base_window_height
            self.game.scale_factor = min(width_scale, height_scale)
            self.game.scale_factor = max(0.8, min(self.game.scale_factor, 2.5))
        
        # Clear existing widgets
        for widget in self.game.root.winfo_children():
            widget.destroy()
        
        # Null out frame references that were just destroyed so they don't cause TclErrors later
        self.game.game_frame = None
        self.game.dialog_frame = None
        
        # Apply color scheme
        bg_color = self.game.current_colors["bg_primary"]
        
        # Create main frame without scrolling - simpler approach
        self.game.main_frame = tk.Frame(self.game.root, bg=bg_color)
        self.game.main_frame.pack(fill=tk.BOTH, expand=True)
        
        # Create menu content
        self._create_simple_menu_content(current_width, current_height)
        
    def _create_simple_menu_content(self, current_width, current_height):
        """Create simple main menu content without scrolling"""
        bg_color = self.game.current_colors["bg_primary"]
        
        # Calculate proportional spacing
        vertical_padding = max(20, int(current_height * 0.03))
        
        # Header container
        header_frame = tk.Frame(self.game.main_frame, bg=bg_color)
        header_frame.pack(pady=(vertical_padding, 0))
        
        # Logo
        logo_frame = tk.Frame(header_frame, bg=bg_color)
        logo_frame.pack(pady=(0, int(vertical_padding * 0.5)))
        
        try:
            logo_path = get_asset_path("assets", "DD Logo.png")
            if os.path.exists(logo_path):
                img = Image.open(logo_path)
                # Scale logo proportionally - 10-13% of window height
                logo_size = max(90, min(150, int(current_height * 0.13)))
                img = img.resize((logo_size, logo_size), Image.LANCZOS)
                self.game.menu_logo_image = ImageTk.PhotoImage(img)
                tk.Label(logo_frame, image=self.game.menu_logo_image, bg=bg_color).pack()
            else:
                tk.Label(logo_frame, text="DD", 
                        font=('Arial', int(current_height * 0.06), 'bold'), 
                        bg=bg_color, fg=self.game.current_colors["text_gold"]).pack()
        except:
            tk.Label(logo_frame, text="DD", 
                    font=('Arial', int(current_height * 0.06), 'bold'), 
                    bg=bg_color, fg=self.game.current_colors["text_gold"]).pack()
        
        # Title
        title_size = max(18, min(28, int(current_height * 0.037)))
        tk.Label(header_frame, text="DICE DUNGEON", 
                font=('Arial', title_size, 'bold'), 
                bg=bg_color, fg=self.game.current_colors["text_gold"]).pack(pady=(0, 5))
        
        # Subtitle
        subtitle_size = max(11, min(16, int(current_height * 0.022)))
        tk.Label(header_frame, text="Explore • Fight • Loot • Survive", 
                font=('Arial', subtitle_size), 
                bg=bg_color, fg=self.game.current_colors["text_primary"]).pack()
        
        # Buttons container
        btn_frame = tk.Frame(self.game.main_frame, bg=bg_color)
        btn_frame.pack(expand=True, pady=vertical_padding)
        
        # Button sizing
        btn_width = max(20, min(26, int(current_width * 0.026)))
        btn_font_size = max(12, min(16, int(current_height * 0.021)))
        btn_pady = max(10, min(14, int(current_height * 0.014)))
        btn_spacing = max(8, min(12, int(current_height * 0.012)))
        
        buttons = [
            ("START ADVENTURE", self.game.start_new_game, self.game.current_colors["button_primary"], '#000000'),
            ("SAVE/LOAD GAME", self.game.load_game, self.game.current_colors["button_secondary"], '#000000'),
            ("SETTINGS", self.game.show_settings, self.game.current_colors["text_purple"], '#ffffff'),
            ("HIGH SCORES", self.game.show_high_scores, self.game.current_colors["text_gold"], '#000000'),
            ("QUIT", self.game.root.quit, '#ff6b6b', '#000000')
        ]
        
        for text, command, bg, fg in buttons:
            btn = tk.Button(btn_frame, text=text, command=command,
                           font=('Arial', btn_font_size, 'bold'), 
                           bg=bg, fg=fg, width=btn_width, pady=btn_pady,
                           relief=tk.RAISED, borderwidth=2,
                           activebackground=self.game.current_colors["button_hover"],
                           activeforeground='#000000')
            btn.pack(pady=btn_spacing)
            self._add_button_hover_effects(btn, bg)
    
    def _create_scrollable_container(self, bg_color, current_width, current_height):
        """Create a scrollable container for the main menu"""
        # Create main canvas for scrolling on small screens
        self.main_canvas = tk.Canvas(self.game.root, bg=bg_color, highlightthickness=0)
        self.main_canvas.pack(fill=tk.BOTH, expand=True)
        
        # Create scrollbar (only show if needed)
        self.scrollbar = tk.Scrollbar(self.game.root, orient="vertical", command=self.main_canvas.yview)
        self.main_canvas.configure(yscrollcommand=self.scrollbar.set)
        
        # Create the actual content frame inside the canvas
        self.game.main_frame = tk.Frame(self.main_canvas, bg=bg_color)
        self.canvas_window = self.main_canvas.create_window((0, 0), window=self.game.main_frame, anchor="nw")
        
        # Configure canvas scrolling
        self.game.main_frame.bind('<Configure>', self._on_frame_configure)
        self.main_canvas.bind('<Configure>', self._on_canvas_configure)
        
        # Bind mousewheel scrolling
        self._bind_mousewheel()
        
    def _create_menu_content(self, current_width, current_height):
        """Create the main menu content with responsive layout"""
        bg_color = self.game.current_colors["bg_primary"]
        
        # Use reasonable sizing that works well for most window sizes
        available_height = max(500, current_height - 40)
        
        # Calculate dynamic spacing with moderate constraints
        base_spacing = max(15, min(25, int(available_height / 22)))
        
        # Add padding to main frame
        self.game.main_frame.configure(padx=20, pady=15)
        
        # Create header section
        self._create_header_section(bg_color, available_height, base_spacing)
        
        # Create button section
        self._create_button_section(bg_color, current_width, available_height, base_spacing)
        
    def _create_header_section(self, bg_color, available_height, base_spacing):
        """Create the header section with logo and titles"""
        # Header section with flexible spacing
        header_frame = tk.Frame(self.game.main_frame, bg=bg_color)
        header_frame.pack(fill=tk.X, pady=(0, base_spacing))
        
        # Logo section
        logo_frame = tk.Frame(header_frame, bg=bg_color)
        logo_frame.pack(pady=base_spacing)
        
        # Load and display logo
        try:
            logo_path = get_asset_path("assets", "DD Logo.png")
            if os.path.exists(logo_path):
                # Calculate logo size - reasonable middle ground
                img = Image.open(logo_path)
                logo_size = max(100, min(140, int(available_height * 0.14)))
                img = img.resize((logo_size, logo_size), Image.LANCZOS)
                self.game.menu_logo_image = ImageTk.PhotoImage(img)
                
                logo_label = tk.Label(logo_frame, image=self.game.menu_logo_image, bg=bg_color)
                logo_label.pack()
            else:
                # Fallback to text if logo not found
                fallback_size = max(28, min(40, int(available_height * 0.07)))
                tk.Label(logo_frame, text="DD", 
                        font=('Arial', self.game.scale_font(fallback_size), 'bold'), 
                        bg=bg_color, fg=self.game.current_colors["text_gold"]).pack()
        except Exception as e:
            # Fallback to text if PIL not available or other error
            fallback_size = max(28, min(40, int(available_height * 0.07)))
            tk.Label(logo_frame, text="DD", 
                    font=('Arial', self.game.scale_font(fallback_size), 'bold'), 
                    bg=bg_color, fg=self.game.current_colors["text_gold"]).pack()
        
        # Title section with balanced font sizing
        title_size = max(18, min(26, int(available_height * 0.038)))
        tk.Label(header_frame, text="DICE DUNGEON", 
                font=('Arial', self.game.scale_font(title_size), 'bold'), 
                bg=bg_color, fg=self.game.current_colors["text_gold"]).pack(pady=(0, int(base_spacing * 0.4)))
        
        subtitle_size = max(11, min(15, int(available_height * 0.024)))
        tk.Label(header_frame, text="Explore • Fight • Loot • Survive", 
                font=('Arial', self.game.scale_font(subtitle_size)), 
                bg=bg_color, fg=self.game.current_colors["text_primary"]).pack()
        
    def _create_button_section(self, bg_color, current_width, available_height, base_spacing):
        """Create the button section with responsive layout"""
        # Button section
        button_frame = tk.Frame(self.game.main_frame, bg=bg_color)
        button_frame.pack(fill=tk.X, pady=base_spacing, expand=True)
        
        # Button container for centering
        btn_container = tk.Frame(button_frame, bg=bg_color)
        btn_container.pack(expand=True)
        
        # Responsive button sizing with balanced constraints
        btn_width = max(18, min(24, int(current_width * 0.024)))
        btn_font_size = max(11, min(15, int(available_height * 0.022)))
        btn_font = ('Arial', self.game.scale_font(btn_font_size), 'bold')
        btn_pady = max(8, min(14, int(available_height * 0.013)))
        btn_spacing = max(8, min(14, int(base_spacing * 0.45)))
        
        # Create buttons with enhanced styling
        buttons = [
            ("START ADVENTURE", self.game.start_new_game, self.game.current_colors["button_primary"], '#000000'),
            ("SAVE/LOAD GAME", self.game.load_game, self.game.current_colors["button_secondary"], '#000000'),
            ("SETTINGS", self.game.show_settings, self.game.current_colors["text_purple"], '#ffffff'),
            ("HIGH SCORES", self.game.show_high_scores, self.game.current_colors["text_gold"], '#000000'),
            ("QUIT", self.game.root.quit, '#ff6b6b', '#000000')
        ]
        
        for text, command, bg, fg in buttons:
            btn = tk.Button(btn_container, text=text, 
                           command=command,
                           font=btn_font, bg=bg, fg=fg,
                           width=btn_width, pady=btn_pady,
                           relief=tk.RAISED, borderwidth=2,
                           activebackground=self.game.current_colors["button_hover"],
                           activeforeground='#000000')
            btn.pack(pady=btn_spacing)
            
            # Add hover effects
            self._add_button_hover_effects(btn, bg)
    
    def _add_button_hover_effects(self, button, original_bg):
        """Add hover effects to a button"""
        hover_color = self.game.current_colors["button_hover"] if original_bg in [
            self.game.current_colors["button_primary"], 
            self.game.current_colors["button_secondary"]
        ] else original_bg
        
        def on_enter(e):
            if hover_color == self.game.current_colors["button_hover"]:
                button.config(bg=hover_color)
            else:
                button.config(relief=tk.SUNKEN)
        
        def on_leave(e):
            button.config(bg=original_bg, relief=tk.RAISED)
        
        button.bind("<Enter>", on_enter)
        button.bind("<Leave>", on_leave)
    
    def _on_frame_configure(self, event=None):
        """Handle frame configuration changes"""
        # Update scroll region when frame size changes
        self.main_canvas.configure(scrollregion=self.main_canvas.bbox("all"))
        
        # Check if scrolling is needed
        self._update_scrollbar_visibility()
    
    def _on_canvas_configure(self, event=None):
        """Handle canvas configuration changes"""
        # Make the frame fill the canvas width
        canvas_width = self.main_canvas.winfo_width()
        self.main_canvas.itemconfig(self.canvas_window, width=canvas_width)
        
        # Update scrollbar visibility
        self._update_scrollbar_visibility()
    
    def _update_scrollbar_visibility(self):
        """Show/hide scrollbar based on content height"""
        self.main_canvas.update_idletasks()
        
        # Get canvas and content heights
        canvas_height = self.main_canvas.winfo_height()
        content_height = self.game.main_frame.winfo_reqheight()
        
        # Show scrollbar if content is taller than canvas
        if content_height > canvas_height:
            self.scrollbar.pack(side="right", fill="y")
        else:
            self.scrollbar.pack_forget()
    
    def _bind_mousewheel(self):
        """Bind mousewheel scrolling to the canvas"""
        def _on_mousewheel(event):
            if self.scrollbar.winfo_viewable():
                self.main_canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")
        
        # Bind to canvas and all child widgets
        def bind_to_mousewheel(widget):
            widget.bind("<MouseWheel>", _on_mousewheel)
            for child in widget.winfo_children():
                bind_to_mousewheel(child)
        
        bind_to_mousewheel(self.game.main_frame)
        self.main_canvas.bind("<MouseWheel>", _on_mousewheel)
    
    def _delayed_main_menu_refresh(self):
        """Delayed refresh of main menu for responsive layout"""
        try:
            # Only refresh if we're still on the main menu
            if (hasattr(self.game, 'main_frame') and 
                self.game.main_frame.winfo_exists() and 
                not hasattr(self.game, 'game_frame')):
                self.show_main_menu()
        except Exception as e:
            # Silently handle any errors during refresh
            pass