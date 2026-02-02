"""
Color Schemes Manager for Dice Dungeon
Handles all color theme definitions and application
"""

# All available color schemes with complete color definitions
COLOR_SCHEMES = {
    "Classic": {
        # Background hierarchy (darkest to lightest)
        "bg_primary": "#2c1810",      # Main dark brown background
        "bg_secondary": "#1a0f08",    # Darker sections
        "bg_dark": "#0f0805",         # Darkest areas
        "bg_panel": "#3d2415",        # Raised panels (lighter)
        "bg_header": "#231408",       # Header bar
        "bg_room": "#2a1810",         # Room description area
        "bg_log": "#1a1008",          # Adventure log
        "bg_minimap": "#1f1408",      # Minimap panel
        
        # Border colors
        "border_gold": "#b8932e",     # Muted gold borders
        "border_dark": "#0a0604",     # Dark borders
        "border_accent": "#8b7355",   # Brown accent borders
        
        # Text colors (bone/parchment theme)
        "text_primary": "#e8dcc4",    # Bone white for main text
        "text_secondary": "#a89884",  # Muted secondary text
        "text_light": "#f5e6d3",      # Lightest text
        "text_gold": "#d4af37",       # Muted gold
        "text_green": "#7fae7f",      # Muted green (healing)
        "text_red": "#c85450",        # Muted red (damage)
        "text_cyan": "#5fa5a5",       # Muted cyan (info)
        "text_purple": "#8b6f9b",     # Muted purple (rare)
        "text_orange": "#d4823b",     # Muted orange (loot)
        "text_white": "#ffffff",      # Pure white (accents)
        "text_magenta": "#b565b5",    # Muted magenta (crit)
        "text_warning": "#d4a537",    # Warning yellow
        
        # Button colors
        "button_primary": "#d4af37",  # Muted gold (main actions)
        "button_secondary": "#5fa5a5",# Muted cyan (secondary)
        "button_success": "#7fae7f",  # Muted green (success)
        "button_danger": "#c85450",   # Muted red (danger)
        "button_disabled": "#4a3a2a", # Disabled state
        "button_hover": "#f0cf5a",    # Lighter gold hover
        
        # HP bar colors
        "hp_full": "#7fae7f",         # Full HP (green)
        "hp_mid": "#d4a537",          # Mid HP (yellow)
        "hp_low": "#c85450",          # Low HP (red)
        "hp_bg": "#1a1008",           # HP bar background
    },
    "Dark": {
        # Background hierarchy - warm dark theme (torch-lit dungeon)
        "bg_primary": "#1d1d1d",      # Charcoal background
        "bg_secondary": "#161616",    # Darker sections
        "bg_dark": "#101010",         # Darkest areas
        "bg_panel": "#282828",        # Raised panels
        "bg_header": "#202020",       # Header bar
        "bg_room": "#1a1a1a",         # Room description area
        "bg_log": "#141414",          # Adventure log
        "bg_minimap": "#1c1c1c",      # Minimap panel
        
        # Border colors
        "border_gold": "#e5a00d",     # Warm amber borders
        "border_dark": "#101010",     # Dark borders
        "border_accent": "#c78c06",   # Darker amber accent
        
        # Text colors - warm and readable
        "text_primary": "#ebdbb2",    # Warm cream text
        "text_secondary": "#a89984",  # Muted tan
        "text_light": "#fbf1c7",      # Light cream
        "text_gold": "#fabd2f",       # Bright amber (important)
        "text_green": "#b8bb26",      # Yellow-green (healing)
        "text_red": "#fb4934",        # Bright red-orange (damage)
        "text_cyan": "#83a598",       # Muted teal (info)
        "text_purple": "#d3869b",     # Dusty rose (rare)
        "text_orange": "#fe8019",     # Bright orange (loot)
        "text_white": "#ffffff",      # Pure white
        "text_magenta": "#d3869b",    # Dusty rose (crit)
        "text_warning": "#fabd2f",    # Amber warning
        
        # Button colors - warm accents
        "button_primary": "#d79921",  # Amber gold (main actions)
        "button_secondary": "#689d6a",# Muted green (secondary)
        "button_success": "#98971a",  # Olive green (success)
        "button_danger": "#cc241d",   # Deep red (danger)
        "button_disabled": "#3c3836", # Dark gray-brown disabled
        "button_hover": "#fabd2f",    # Bright amber hover
        
        # HP bar colors
        "hp_full": "#b8bb26",         # Full HP (yellow-green)
        "hp_mid": "#fabd2f",          # Mid HP (amber)
        "hp_low": "#fb4934",          # Low HP (red-orange)
        "hp_bg": "#1a1a1a",           # HP bar background
    },
    "Light": {
        # Background hierarchy - parchment/cream theme
        "bg_primary": "#f5f0e6",      # Warm cream background
        "bg_secondary": "#ebe4d4",    # Slightly darker cream
        "bg_dark": "#ddd4c0",         # Darkest cream areas
        "bg_panel": "#faf7f0",        # Lighter raised panels
        "bg_header": "#e8e0d0",       # Header bar
        "bg_room": "#f0ebe0",         # Room description area
        "bg_log": "#e5dfd0",          # Adventure log
        "bg_minimap": "#ebe5d8",      # Minimap panel
        
        # Border colors
        "border_gold": "#8b7355",     # Brown borders
        "border_dark": "#a89070",     # Medium brown borders
        "border_accent": "#c4a87c",   # Light brown accent
        
        # Text colors (dark ink theme)
        "text_primary": "#2c1810",    # Dark brown for main text
        "text_secondary": "#5a4a3a",  # Medium brown
        "text_light": "#1a0f08",      # Darkest text
        "text_gold": "#8b6914",       # Dark gold
        "text_green": "#2d6a2d",      # Dark green (healing)
        "text_red": "#a83232",        # Dark red (damage)
        "text_cyan": "#1a6a6a",       # Dark cyan (info)
        "text_purple": "#5a3a7a",     # Dark purple (rare)
        "text_orange": "#a85a1a",     # Dark orange (loot)
        "text_white": "#2c1810",      # Dark (replaces white)
        "text_magenta": "#8a3a8a",    # Dark magenta (crit)
        "text_warning": "#8b6914",    # Dark warning
        
        # Button colors
        "button_primary": "#8b6914",  # Dark gold (main actions)
        "button_secondary": "#1a6a6a",# Dark cyan (secondary)
        "button_success": "#2d6a2d",  # Dark green (success)
        "button_danger": "#a83232",   # Dark red (danger)
        "button_disabled": "#c4b8a0", # Light disabled
        "button_hover": "#a88020",    # Lighter gold hover
        
        # HP bar colors
        "hp_full": "#2d6a2d",         # Full HP (dark green)
        "hp_mid": "#8b6914",          # Mid HP (dark gold)
        "hp_low": "#a83232",          # Low HP (dark red)
        "hp_bg": "#ddd4c0",           # HP bar background
    },
    "Neon": {
        # Background hierarchy - cyberpunk dark theme
        "bg_primary": "#0d0d0d",      # Near black background
        "bg_secondary": "#1a1a1a",    # Slightly lighter
        "bg_dark": "#050505",         # Darkest areas
        "bg_panel": "#252525",        # Raised panels
        "bg_header": "#151515",       # Header bar
        "bg_room": "#1f1f1f",         # Room description area
        "bg_log": "#121212",          # Adventure log
        "bg_minimap": "#181818",      # Minimap panel
        
        # Border colors
        "border_gold": "#ff00ff",     # Hot pink borders
        "border_dark": "#1a0a1a",     # Dark purple borders
        "border_accent": "#00ffff",   # Cyan accent borders
        
        # Text colors (neon glow theme)
        "text_primary": "#ffffff",    # Pure white for main text
        "text_secondary": "#b0b0b0",  # Gray secondary
        "text_light": "#ffffff",      # Brightest text
        "text_gold": "#ffff00",       # Neon yellow (replaces gold)
        "text_green": "#00ff00",      # Neon green (healing)
        "text_red": "#ff0040",        # Hot pink-red (damage)
        "text_cyan": "#00ffff",       # Neon cyan (info)
        "text_purple": "#bf00ff",     # Neon purple (rare)
        "text_orange": "#ff8000",     # Neon orange (loot)
        "text_white": "#ffffff",      # Pure white
        "text_magenta": "#ff00ff",    # Neon magenta (crit)
        "text_warning": "#ffff00",    # Neon yellow warning
        
        # Button colors
        "button_primary": "#ff00ff",  # Magenta (main actions)
        "button_secondary": "#00ffff",# Cyan (secondary)
        "button_success": "#00ff00",  # Neon green (success)
        "button_danger": "#ff0040",   # Hot pink (danger)
        "button_disabled": "#404040", # Gray disabled
        "button_hover": "#ff80ff",    # Lighter magenta hover
        
        # HP bar colors
        "hp_full": "#00ff00",         # Full HP (neon green)
        "hp_mid": "#ffff00",          # Mid HP (neon yellow)
        "hp_low": "#ff0040",          # Low HP (hot pink)
        "hp_bg": "#1a1a1a",           # HP bar background
    },
    "Forest": {
        # Background hierarchy - deep forest theme
        "bg_primary": "#1a2f1a",      # Deep forest green background
        "bg_secondary": "#0f1f0f",    # Darker forest sections
        "bg_dark": "#0a150a",         # Darkest forest areas
        "bg_panel": "#2a4a2a",        # Mossy raised panels
        "bg_header": "#152515",       # Header bar
        "bg_room": "#1f351f",         # Room description area
        "bg_log": "#122012",          # Adventure log
        "bg_minimap": "#182818",      # Minimap panel
        
        # Border colors
        "border_gold": "#8fbc8f",     # Sage green borders
        "border_dark": "#0a150a",     # Dark green borders
        "border_accent": "#6b8e6b",   # Moss accent borders
        
        # Text colors (natural forest theme)
        "text_primary": "#e8f5e8",    # Pale green-white for main text
        "text_secondary": "#a8c8a8",  # Muted sage
        "text_light": "#f0f8f0",      # Lightest text
        "text_gold": "#daa520",       # Goldenrod (autumn leaf)
        "text_green": "#90ee90",      # Light green (healing)
        "text_red": "#cd5c5c",        # Indian red (damage)
        "text_cyan": "#66cdaa",       # Medium aquamarine (info)
        "text_purple": "#9370db",     # Medium purple (rare)
        "text_orange": "#deb887",     # Burlywood (loot)
        "text_white": "#f5f5f5",      # Off-white
        "text_magenta": "#da70d6",    # Orchid (crit)
        "text_warning": "#f0e68c",    # Khaki warning
        
        # Button colors
        "button_primary": "#daa520",  # Goldenrod (main actions)
        "button_secondary": "#66cdaa",# Aquamarine (secondary)
        "button_success": "#90ee90",  # Light green (success)
        "button_danger": "#cd5c5c",   # Indian red (danger)
        "button_disabled": "#3a5a3a", # Dark green disabled
        "button_hover": "#ffd700",    # Gold hover
        
        # HP bar colors
        "hp_full": "#90ee90",         # Full HP (light green)
        "hp_mid": "#f0e68c",          # Mid HP (khaki)
        "hp_low": "#cd5c5c",          # Low HP (indian red)
        "hp_bg": "#122012",           # HP bar background
    }
}

# Default color scheme
DEFAULT_SCHEME = "Classic"


class ColorManager:
    """
    Manages color schemes for the game.
    Provides methods to get, set, and apply color schemes.
    """
    
    def __init__(self, game):
        """
        Initialize the ColorManager.
        
        Args:
            game: Reference to the main game instance
        """
        self.game = game
    
    def get_scheme(self, scheme_name):
        """
        Get a color scheme by name.
        
        Args:
            scheme_name: Name of the color scheme
            
        Returns:
            dict: Color scheme dictionary, or Classic if not found
        """
        if scheme_name in COLOR_SCHEMES:
            return COLOR_SCHEMES[scheme_name]
        return COLOR_SCHEMES[DEFAULT_SCHEME]
    
    def get_available_schemes(self):
        """
        Get list of available color scheme names.
        
        Returns:
            list: List of scheme names
        """
        return list(COLOR_SCHEMES.keys())
    
    def is_valid_scheme(self, scheme_name):
        """
        Check if a scheme name is valid.
        
        Args:
            scheme_name: Name to check
            
        Returns:
            bool: True if valid, False otherwise
        """
        return scheme_name in COLOR_SCHEMES
    
    def apply_scheme(self, scheme_name):
        """
        Apply a color scheme to the game.
        
        Args:
            scheme_name: Name of the scheme to apply
            
        Returns:
            dict: The applied color scheme
        """
        if not self.is_valid_scheme(scheme_name):
            scheme_name = DEFAULT_SCHEME
        
        self.game.settings["color_scheme"] = scheme_name
        self.game.current_colors = COLOR_SCHEMES[scheme_name]
        return self.game.current_colors
    
    def get_current_scheme_name(self):
        """
        Get the name of the currently applied scheme.
        
        Returns:
            str: Current scheme name
        """
        return self.game.settings.get("color_scheme", DEFAULT_SCHEME)
    
    def get_color(self, color_key):
        """
        Get a specific color from the current scheme.
        
        Args:
            color_key: Key of the color (e.g., "bg_primary", "text_gold")
            
        Returns:
            str: Hex color code, or None if not found
        """
        return self.game.current_colors.get(color_key)


# Module-level helper functions for use without game instance
def get_all_schemes():
    """Get all color scheme definitions."""
    return COLOR_SCHEMES

def get_scheme_names():
    """Get list of all scheme names."""
    return list(COLOR_SCHEMES.keys())

def get_default_scheme():
    """Get the default color scheme."""
    return COLOR_SCHEMES[DEFAULT_SCHEME]

def get_scheme_by_name(name):
    """Get a specific scheme by name, with fallback to default."""
    return COLOR_SCHEMES.get(name, COLOR_SCHEMES[DEFAULT_SCHEME])
