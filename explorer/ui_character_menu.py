"""
Character Menu UI for Dice Dungeon Explorer
Handles the character stats/status screen
"""

import tkinter as tk
from tkinter import ttk
from typing import TYPE_CHECKING, Callable

if TYPE_CHECKING:
    from dice_dungeon_explorer import DiceDungeonExplorer


def create_tooltip_follower(game: 'DiceDungeonExplorer', widget, get_tooltip_text: Callable[[], str]):
    """Create a tooltip that follows the mouse cursor and shows detailed stat breakdowns"""
    tooltip = None
    
    def show_tooltip(event):
        nonlocal tooltip
        if tooltip:
            tooltip.destroy()
        
        tooltip_text = get_tooltip_text()
        if not tooltip_text:
            return
            
        tooltip = tk.Toplevel(widget)
        tooltip.wm_overrideredirect(True)
        tooltip.wm_geometry(f"+{event.x_root + 15}+{event.y_root + 15}")
        
        label = tk.Label(tooltip, text=tooltip_text, justify='left',
                       bg="#ffffe0", fg="#000000", relief=tk.SOLID, borderwidth=1,
                       font=('Arial', 9), padx=8, pady=5)
        label.pack()
    
    def update_tooltip(event):
        nonlocal tooltip
        if tooltip:
            tooltip.wm_geometry(f"+{event.x_root + 15}+{event.y_root + 15}")
    
    def hide_tooltip(event):
        nonlocal tooltip
        if tooltip:
            tooltip.destroy()
            tooltip = None
    
    widget.bind('<Enter>', show_tooltip)
    widget.bind('<Motion>', update_tooltip)
    widget.bind('<Leave>', hide_tooltip)


def show_character_status(game: 'DiceDungeonExplorer'):
    """Show comprehensive character status with tabbed interface"""
    if game.dialog_frame:
        game.dialog_frame.destroy()
    
    # Responsive sizing - larger for tabs
    dialog_width, dialog_height = game.get_responsive_dialog_size(700, 700, 0.75, 0.9)
    
    game.dialog_frame = tk.Frame(game.game_frame, bg=game.current_colors["bg_panel"], 
                                  relief=tk.RIDGE, borderwidth=3)
    game.dialog_frame.place(relx=0.5, rely=0.5, anchor='center', 
                            width=dialog_width, height=dialog_height)
    
    # Header with close button
    header_frame = tk.Frame(game.dialog_frame, bg=game.current_colors["bg_panel"])
    header_frame.pack(fill=tk.X, pady=(10, 5))
    
    # Red X close button (top right)
    close_btn = tk.Label(header_frame, text="✕", font=('Arial', 16, 'bold'),
                        bg=game.current_colors["bg_panel"], fg='#ff4444',
                        cursor="hand2", padx=5)
    close_btn.place(relx=1.0, rely=0.0, anchor='ne', x=-10, y=0)
    close_btn.bind('<Button-1>', lambda e: game.close_dialog())
    close_btn.bind('<Enter>', lambda e: close_btn.config(fg='#ff0000'))
    close_btn.bind('<Leave>', lambda e: close_btn.config(fg='#ff4444'))
    
    # Create tabbed notebook
    style = ttk.Style()
    style.theme_use('default')
    style.configure('Custom.TNotebook', background=game.current_colors["bg_panel"], borderwidth=0)
    style.configure('Custom.TNotebook.Tab', 
                   background=game.current_colors["bg_dark"],
                   foreground=game.current_colors["text_cyan"],
                   padding=[20, 10],
                   font=('Arial', 11, 'bold'))
    style.map('Custom.TNotebook.Tab',
             background=[('selected', game.current_colors["bg_panel"])],
             foreground=[('selected', game.current_colors["text_gold"])])
    
    notebook = ttk.Notebook(game.dialog_frame, style='Custom.TNotebook')
    notebook.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 10))
    
    # Create tabs
    char_tab = tk.Frame(notebook, bg=game.current_colors["bg_primary"])
    stats_tab = tk.Frame(notebook, bg=game.current_colors["bg_primary"])
    lore_tab = tk.Frame(notebook, bg=game.current_colors["bg_primary"])
    
    notebook.add(char_tab, text="Character")
    notebook.add(stats_tab, text="Game Stats")
    notebook.add(lore_tab, text="Lore Codex")
    
    # Populate Character tab
    _populate_character_tab(game, char_tab)
    
    # Lazy load other tabs
    def on_tab_changed(event):
        selected_tab = event.widget.select()
        tab_text = event.widget.tab(selected_tab, "text")
        
        if tab_text == "Game Stats" and not stats_tab.winfo_children():
            _populate_stats_tab(game, stats_tab)
        elif tab_text == "Lore Codex" and not lore_tab.winfo_children():
            _populate_lore_tab(game, lore_tab)
    
    notebook.bind('<<NotebookTabChanged>>', on_tab_changed)


def _populate_character_tab(game: 'DiceDungeonExplorer', parent):
    """Populate the Character tab"""
    
    # Create scrollable area
    canvas = tk.Canvas(parent, bg=game.current_colors["bg_primary"], highlightthickness=0)
    scrollbar = tk.Scrollbar(parent, orient="vertical", command=canvas.yview, width=10,
                            bg=game.current_colors["bg_primary"], troughcolor=game.current_colors["bg_dark"])
    scroll_frame = tk.Frame(canvas, bg=game.current_colors["bg_primary"])
    
    scroll_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
    
    def update_width(event=None):
        canvas.itemconfig(canvas_window, width=canvas.winfo_width()-10)
    
    canvas_window = canvas.create_window((0, 0), window=scroll_frame, anchor="nw")
    canvas.bind("<Configure>", update_width)
    canvas.configure(yscrollcommand=scrollbar.set)
    
    # Setup mousewheel scrolling
    game.setup_mousewheel_scrolling(canvas)
    
    canvas.pack(side="left", fill="both", expand=True, padx=10, pady=5)
    scrollbar.pack(side="right", fill="y")
    
    # === EQUIPPED GEAR SECTION ===
    gear_section = tk.Frame(scroll_frame, bg=game.current_colors["bg_panel"], relief=tk.RIDGE, borderwidth=2)
    gear_section.pack(fill=tk.X, padx=10, pady=10)
    
    tk.Label(gear_section, text="◊ EQUIPPED GEAR", font=('Arial', 14, 'bold'),
            bg=game.current_colors["bg_panel"], fg=game.current_colors["text_cyan"],
            pady=5).pack()
    
    # Show each equipment slot
    for slot_name, slot_key in [("Weapon", "weapon"), ("Armor", "armor"), ("Accessory", "accessory"), ("Backpack", "backpack")]:
        slot_frame = tk.Frame(gear_section, bg=game.current_colors["bg_dark"], relief=tk.FLAT, borderwidth=1)
        slot_frame.pack(fill=tk.X, padx=10, pady=3)
        
        equipped_item = game.equipped_items.get(slot_key)
        if equipped_item:
            item_def = game.item_definitions.get(equipped_item, {})
            
            # Build effect string from actual bonus properties
            effect_parts = []
            if 'damage_bonus' in item_def: 
                effect_parts.append(f"+{item_def['damage_bonus']} DMG")
            if 'crit_bonus' in item_def: 
                effect_parts.append(f"+{int(item_def['crit_bonus']*100)}% CRIT")
            # Show combat ability instead of passive reroll for Mystic Ring
            if 'combat_ability' in item_def:
                if item_def['combat_ability'] == 'reroll':
                    effect_parts.append("COMBAT: +1 REROLL (Once)")
            elif 'reroll_bonus' in item_def: 
                effect_parts.append(f"+{item_def['reroll_bonus']} REROLL")
            if 'max_hp_bonus' in item_def: 
                effect_parts.append(f"+{item_def['max_hp_bonus']} MAX HP")
            if 'armor_bonus' in item_def: 
                effect_parts.append(f"+{item_def['armor_bonus']} ARMOR")
            if 'inventory_bonus' in item_def: 
                effect_parts.append(f"+{item_def['inventory_bonus']} INV SLOTS")
            
            # Show durability if equipment has it
            durability_str = ""
            max_dur = item_def.get('max_durability', 0)
            if max_dur > 0:
                # Ensure item is in durability tracking
                if equipped_item not in game.equipment_durability:
                    game.equipment_durability[equipped_item] = max_dur
                
                current_dur = game.equipment_durability[equipped_item]
                durability_percent = int((current_dur / max_dur) * 100)
                durability_str = f" [{durability_percent}% condition]"
            
            effect_str = " | ".join(effect_parts) if effect_parts else "No bonuses"
            
            tk.Label(slot_frame, text=f"{slot_name}: {equipped_item}{durability_str}",
                    font=('Arial', 11, 'bold'), bg=game.current_colors["bg_dark"],
                    fg=game.current_colors["text_gold"], anchor='w', padx=10, pady=3).pack(anchor='w')
            tk.Label(slot_frame, text=f"  {effect_str}",
                    font=('Arial', 9), bg=game.current_colors["bg_dark"],
                    fg=game.current_colors["text_green"], anchor='w', padx=10, pady=2).pack(anchor='w')
        else:
            tk.Label(slot_frame, text=f"{slot_name}: (Empty)",
                    font=('Arial', 11), bg=game.current_colors["bg_dark"],
                    fg=game.current_colors["text_secondary"], anchor='w', padx=10, pady=5).pack(anchor='w')
    
    # === CHARACTER STATS SECTION ===
    stats_section = tk.Frame(scroll_frame, bg=game.current_colors["bg_panel"], relief=tk.RIDGE, borderwidth=2)
    stats_section.pack(fill=tk.X, padx=10, pady=10)
    
    tk.Label(stats_section, text="⚔ CHARACTER STATS", font=('Arial', 14, 'bold'),
            bg=game.current_colors["bg_panel"], fg=game.current_colors["text_red"],
            pady=5).pack()
    
    stats_grid = tk.Frame(stats_section, bg=game.current_colors["bg_panel"])
    stats_grid.pack(padx=10, pady=5, fill=tk.X)
    
    # Calculate bonuses from equipment
    equipment_damage = 0
    equipment_crit = 0
    equipment_heal = 0
    equipment_reroll = 0
    equipment_multiplier = 1.0
    equipment_max_hp = 0
    
    equipment_sources = {
        'damage': [],
        'crit': [],
        'heal': [],
        'reroll': [],
        'multiplier': [],
        'max_hp': []
    }
    
    for slot, item_name in game.equipped_items.items():
        if item_name and item_name in game.item_definitions:
            item_def = game.item_definitions[item_name]
            floor_level = game.equipment_floor_level.get(item_name, game.floor)
            floor_bonus = max(0, floor_level - 1)
            
            if 'damage_bonus' in item_def:
                base_damage = item_def['damage_bonus']
                total_damage = base_damage + floor_bonus
                equipment_damage += total_damage
                equipment_sources['damage'].append((item_name, total_damage))
            
            if 'crit_bonus' in item_def:
                crit_bonus = item_def['crit_bonus']
                equipment_crit += crit_bonus
                equipment_sources['crit'].append((item_name, crit_bonus))
            
            if 'heal_bonus' in item_def:
                heal_bonus = item_def['heal_bonus']
                equipment_heal += heal_bonus
                equipment_sources['heal'].append((item_name, heal_bonus))
            
            if 'reroll_bonus' in item_def:
                reroll_bonus = item_def['reroll_bonus']
                equipment_reroll += reroll_bonus
                equipment_sources['reroll'].append((item_name, reroll_bonus))
            
            # Check for combat ability reroll (Mystic Ring)
            if 'combat_ability' in item_def and item_def['combat_ability'] == 'reroll':
                equipment_reroll += 1
                equipment_sources['reroll'].append((item_name, 1))
            
            if 'multiplier' in item_def:
                mult = item_def['multiplier']
                equipment_multiplier *= mult
                equipment_sources['multiplier'].append((item_name, mult))
            
            if 'max_hp_bonus' in item_def:
                hp_bonus = item_def['max_hp_bonus']
                equipment_max_hp += hp_bonus
                equipment_sources['max_hp'].append((item_name, hp_bonus))
    
    permanent_damage = game.damage_bonus - equipment_damage
    permanent_crit = game.crit_chance - equipment_crit
    permanent_heal = game.heal_bonus - equipment_heal
    permanent_reroll = game.reroll_bonus - equipment_reroll
    permanent_multiplier = game.multiplier / equipment_multiplier
    
    # Calculate health breakdown
    base_max_hp = 50  # Base starting HP
    permanent_max_hp = game.max_health - base_max_hp - equipment_max_hp
    
    # Build tooltip text generators (with base stat showing total first)
    def dice_tooltip():
        base_dice = 3  # Always start with 3 dice
        extra_dice = game.num_dice - base_dice
        if extra_dice > 0:
            dice_word = "die" if extra_dice == 1 else "dice"
            return f"Total Dice: {game.num_dice}\n\nBase: {base_dice} dice\nPermanent Upgrade: +{extra_dice} {dice_word}"
        else:
            return f"Total Dice: {game.num_dice}\n\nBase: {base_dice} dice"
    
    def damage_tooltip():
        lines = [f"Total Damage Bonus: +{game.damage_bonus}\n"]
        if permanent_damage > 0:
            lines.append(f"Permanent Upgrade: +{permanent_damage}")
        if equipment_sources['damage']:
            for item_name, bonus in equipment_sources['damage']:
                lines.append(f"{item_name}: +{bonus}")
        return "\n".join(lines) if len(lines) > 1 else "No damage bonus"
    
    def multiplier_tooltip():
        lines = [f"Total Multiplier: {game.multiplier:.2f}x\n"]
        if abs(permanent_multiplier - 1.0) > 0.01:
            lines.append(f"Permanent Upgrade: {permanent_multiplier:.2f}x")
        if equipment_sources['multiplier']:
            for item_name, mult in equipment_sources['multiplier']:
                lines.append(f"{item_name}: {mult:.2f}x")
        return "\n".join(lines) if len(lines) > 1 else "Base multiplier: 1.00x"
    
    def crit_tooltip():
        base_crit = 0.1  # Base 10% crit chance
        lines = [f"Total Crit Chance: {game.crit_chance*100:.1f}%\n"]
        lines.append(f"Base: {int(base_crit*100)}%")
        permanent_crit_bonus = permanent_crit - base_crit
        if abs(permanent_crit_bonus) > 0.001:
            lines.append(f"Permanent Upgrade: +{int(permanent_crit_bonus*100)}%")
        if equipment_sources['crit']:
            for item_name, bonus in equipment_sources['crit']:
                lines.append(f"{item_name}: +{int(bonus*100)}%")
        return "\n".join(lines)
    
    def heal_tooltip():
        lines = [f"Total Healing Bonus: +{game.heal_bonus} HP\n"]
        if permanent_heal > 0:
            lines.append(f"Permanent Upgrade: +{permanent_heal} HP")
        if equipment_sources['heal']:
            for item_name, bonus in equipment_sources['heal']:
                lines.append(f"{item_name}: +{bonus} HP")
        return "\n".join(lines) if len(lines) > 1 else "No healing bonus"
    
    def reroll_tooltip():
        lines = [f"Total Bonus Rerolls: +{game.reroll_bonus}\n"]
        if permanent_reroll > 0:
            lines.append(f"Permanent Upgrade: +{permanent_reroll}")
        if equipment_sources['reroll']:
            for item_name, bonus in equipment_sources['reroll']:
                lines.append(f"{item_name}: +{bonus}")
        return "\n".join(lines) if len(lines) > 1 else "No reroll bonus"
    
    def health_tooltip():
        lines = [f"Total Max Health: {game.max_health} HP\n"]
        lines.append(f"Base: {base_max_hp} HP")
        if permanent_max_hp > 0:
            lines.append(f"Permanent Upgrades: +{permanent_max_hp} HP")
        if equipment_sources['max_hp']:
            for item_name, bonus in equipment_sources['max_hp']:
                lines.append(f"{item_name}: +{bonus} HP")
        return "\n".join(lines)
    
    combat_stats = [
        ("Health", f"{game.health}/{game.max_health}", health_tooltip),
        ("Dice Pool", f"{game.num_dice} dice", dice_tooltip),
        ("Base Damage Bonus", f"+{permanent_damage}", damage_tooltip),
        ("Damage Multiplier", f"{game.multiplier:.2f}x", multiplier_tooltip),
        ("Critical Hit Chance", f"{game.crit_chance*100:.1f}%", crit_tooltip),
        ("Healing Bonus", f"+{game.heal_bonus} HP", heal_tooltip),
        ("Bonus Rerolls", f"+{game.reroll_bonus}", reroll_tooltip),
    ]
    
    for i, (label, value, tooltip_func) in enumerate(combat_stats):
        row_frame = tk.Frame(stats_grid, bg=game.current_colors["bg_dark"])
        row_frame.pack(fill=tk.X, pady=2)
        
        label_widget = tk.Label(row_frame, text=label+":", font=('Arial', 10),
                bg=game.current_colors["bg_dark"], fg=game.current_colors["text_white"],
                anchor='w', width=22)
        label_widget.pack(side=tk.LEFT, padx=10)
        
        value_widget = tk.Label(row_frame, text=value, font=('Arial', 10, 'bold'),
                bg=game.current_colors["bg_dark"], fg=game.current_colors["text_cyan"],
                anchor='e')
        value_widget.pack(side=tk.RIGHT, padx=10)
        
        # Add tooltips that follow cursor
        create_tooltip_follower(game, label_widget, tooltip_func)
        create_tooltip_follower(game, value_widget, tooltip_func)
        create_tooltip_follower(game, row_frame, tooltip_func)
    
    # === ACTIVE EFFECTS SECTION ===
    effects_section = tk.Frame(scroll_frame, bg=game.current_colors["bg_panel"], relief=tk.RIDGE, borderwidth=2)
    effects_section.pack(fill=tk.X, padx=10, pady=10)
    
    tk.Label(effects_section, text="✨ ACTIVE EFFECTS", font=('Arial', 14, 'bold'),
            bg=game.current_colors["bg_panel"], fg=game.current_colors["text_purple"],
            pady=5).pack()
    
    # Show temp effects
    effects_found = False
    
    if game.temp_shield > 0:
        effects_found = True
        tk.Label(effects_section, text=f"◊ Shield: {game.temp_shield} HP",
                font=('Arial', 10), bg=game.current_colors["bg_panel"],
                fg=game.current_colors["text_cyan"], pady=2).pack()
    
    if game.shop_discount > 0:
        effects_found = True
        tk.Label(effects_section, text=f"◉ Shop Discount: {int(game.shop_discount*100)}%",
                font=('Arial', 10), bg=game.current_colors["bg_panel"],
                fg=game.current_colors["text_gold"], pady=2).pack()
    
    if getattr(game, 'combat_accuracy_penalty', 0) > 0:
        effects_found = True
        tk.Label(effects_section, text=f"≈ Accuracy Penalty: {int(game.combat_accuracy_penalty*100)}%",
                font=('Arial', 10), bg=game.current_colors["bg_panel"],
                fg=game.current_colors["text_red"], pady=2).pack()
    
    # Show flags and statuses from content system
    if game.flags.get('disarm_token', 0) > 0:
        effects_found = True
        tk.Label(effects_section, text=f"⚙ Disarm Tokens: {game.flags['disarm_token']}",
                font=('Arial', 10), bg=game.current_colors["bg_panel"],
                fg=game.current_colors["text_green"], pady=2).pack()
    
    if game.flags.get('escape_token', 0) > 0:
        effects_found = True
        tk.Label(effects_section, text=f"» Escape Tokens: {game.flags['escape_token']}",
                font=('Arial', 10), bg=game.current_colors["bg_panel"],
                fg=game.current_colors["text_green"], pady=2).pack()
    
    # Show any temp effects from content system
    for effect_name, effect_data in game.temp_effects.items():
        effects_found = True
        duration = effect_data.get('duration', '?')
        
        # Format effect name for display
        display_name = effect_name.replace('_', ' ').title()
        
        # Special formatting for specific effects
        if 'gold_mult' in effect_name:
            mult_value = effect_data.get('value', 0)
            display_name = f"Gold Bonus: +{int(mult_value * 100)}%"
        elif 'damage_bonus' in effect_name:
            dmg_value = effect_data.get('value', 0)
            display_name = f"Damage Bonus: +{dmg_value}"
        elif 'crit_bonus' in effect_name:
            crit_value = effect_data.get('value', 0)
            display_name = f"Crit Bonus: +{int(crit_value * 100)}%"
        
        tk.Label(effects_section, text=f"⚡ {display_name}: {duration}",
                font=('Arial', 10), bg=game.current_colors["bg_panel"],
                fg=game.current_colors["text_magenta"], pady=2).pack()
    
    # Show statuses
    for status in game.flags.get('statuses', []):
        effects_found = True
        tk.Label(effects_section, text=f"✦ {status}",
                font=('Arial', 10), bg=game.current_colors["bg_panel"],
                fg=game.current_colors["text_purple"], pady=2).pack()
    
    if not effects_found:
        tk.Label(effects_section, text="(No active effects)",
                font=('Arial', 10, 'italic'), bg=game.current_colors["bg_panel"],
                fg=game.current_colors["text_secondary"], pady=10).pack()
    
    # === RESOURCES SECTION ===
    resources_section = tk.Frame(scroll_frame, bg=game.current_colors["bg_panel"], relief=tk.RIDGE, borderwidth=2)
    resources_section.pack(fill=tk.X, padx=10, pady=10)
    
    tk.Label(resources_section, text="◇ RESOURCES", font=('Arial', 14, 'bold'),
            bg=game.current_colors["bg_panel"], fg=game.current_colors["text_gold"],
            pady=5).pack()
    
    resources_grid = tk.Frame(resources_section, bg=game.current_colors["bg_panel"])
    resources_grid.pack(padx=10, pady=5, fill=tk.X)
    
    resources = [
        ("Gold", f"{game.gold}", game.current_colors["text_gold"]),
        ("Inventory Space", f"{len(game.inventory)}/{game.max_inventory}", game.current_colors["text_cyan"]),
        ("Rest Cooldown", f"{game.rest_cooldown} rooms" if game.rest_cooldown > 0 else "Ready", 
         game.current_colors["text_green"] if game.rest_cooldown == 0 else game.current_colors["text_red"]),
    ]
    
    for label, value, color in resources:
        row_frame = tk.Frame(resources_grid, bg=game.current_colors["bg_dark"])
        row_frame.pack(fill=tk.X, pady=2)
        
        tk.Label(row_frame, text=label+":", font=('Arial', 10),
                bg=game.current_colors["bg_dark"], fg=game.current_colors["text_white"],
                anchor='w', width=22).pack(side=tk.LEFT, padx=10)
        tk.Label(row_frame, text=value, font=('Arial', 10, 'bold'),
                bg=game.current_colors["bg_dark"], fg=color,
                anchor='e').pack(side=tk.RIGHT, padx=10)
    
    # Bind mousewheel to all child widgets
    def bind_mousewheel_to_tree(widget):
        def on_mousewheel(event):
            canvas.yview_scroll(int(-1*(event.delta/120)), "units")
        widget.bind("<MouseWheel>", on_mousewheel, add='+')
        for child in widget.winfo_children():
            bind_mousewheel_to_tree(child)
    bind_mousewheel_to_tree(scroll_frame)


def _populate_stats_tab(game: 'DiceDungeonExplorer', parent):
    """Populate the Game Stats tab"""
    canvas = tk.Canvas(parent, bg=game.current_colors["bg_secondary"], highlightthickness=0)
    scrollbar = tk.Scrollbar(parent, orient="vertical", command=canvas.yview, width=10,
                            bg=game.current_colors["bg_secondary"], troughcolor=game.current_colors["bg_dark"])
    scrollable_frame = tk.Frame(canvas, bg=game.current_colors["bg_secondary"])
    
    scrollable_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
    
    def update_width(event=None):
        canvas.itemconfig(canvas_window, width=canvas.winfo_width()-10)
    
    canvas_window = canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
    canvas.bind("<Configure>", update_width)
    canvas.configure(yscrollcommand=scrollbar.set)
    game.setup_mousewheel_scrolling(canvas)
    
    stats_data = game.stats
    
    # Combat Statistics
    _add_stats_section(game, scrollable_frame, "⚔️ COMBAT", [
        ("Enemies Encountered", stats_data.get("enemies_encountered", 0)),
        ("Enemies Fled", stats_data.get("enemies_fled", 0)),
        ("Enemies Defeated", stats_data.get("enemies_defeated", 0)),
        ("Mini-Bosses Defeated", stats_data.get("mini_bosses_defeated", 0)),
        ("Bosses Defeated", stats_data.get("bosses_defeated", 0)),
        ("Total Damage Dealt", stats_data.get("total_damage_dealt", 0)),
        ("Total Damage Taken", stats_data.get("total_damage_taken", 0)),
        ("Highest Single Damage", stats_data.get("highest_single_damage", 0)),
        ("Critical Hits", stats_data.get("critical_hits", 0))
    ])
    
    _add_stats_section(game, scrollable_frame, "§ ECONOMY", [
        ("Gold Found", stats_data.get("gold_found", 0)),
        ("Gold Spent", stats_data.get("gold_spent", 0)),
        ("Items Purchased", stats_data.get("items_purchased", 0)),
        ("Items Sold", stats_data.get("items_sold", 0))
    ])
    
    _add_stats_section(game, scrollable_frame, "◈ ITEMS", [
        ("Items Found", stats_data.get("items_found", 0)),
        ("Items Used", stats_data.get("items_used", 0)),
        ("Potions Used", stats_data.get("potions_used", 0)),
        ("Containers Searched", stats_data.get("containers_searched", 0))
    ])
    
    _add_stats_section(game, scrollable_frame, "◊️ EQUIPMENT", [
        ("Weapons Broken", stats_data.get("weapons_broken", 0)),
        ("Armor Broken", stats_data.get("armor_broken", 0)),
        ("Weapons Repaired", stats_data.get("weapons_repaired", 0)),
        ("Armor Repaired", stats_data.get("armor_repaired", 0))
    ])
    
    lore_data = stats_data.get("lore_found", {})
    _add_stats_section(game, scrollable_frame, "📜 LORE COLLECTED", [
        ("Guard Journals", f"{lore_data.get('Guard Journal', 0)}/16"),
        ("Quest Notices", f"{lore_data.get('Quest Notice', 0)}/12"),
        ("Scrawled Notes", f"{lore_data.get('Scrawled Note', 0)}/10"),
        ("Training Manuals", f"{lore_data.get('Training Manual Page', 0)}/10"),
        ("Pressed Pages", f"{lore_data.get('Pressed Page', 0)}/6"),
        ("Surgeon's Notes", f"{lore_data.get('Surgeon' + chr(39) + 's Note', 0)}/6"),
        ("Puzzle Notes", f"{lore_data.get('Puzzle Note', 0)}/4"),
        ("Star Charts", f"{lore_data.get('Star Chart', 0)}/4"),
        ("Map Scraps", f"{lore_data.get('Cracked Map Scrap', 0)}/10"),
        ("Old Letters", f"{lore_data.get('Old Letter', 0)}/12"),
        ("Prayer Strips", f"{lore_data.get('Prayer Strip', 0)}/10")
    ])
    
    _add_stats_section(game, scrollable_frame, "🗺️ EXPLORATION", [
        ("Rooms Explored", stats_data.get("rooms_explored", 0)),
        ("Times Rested", stats_data.get("times_rested", 0)),
        ("Stairs Used", stats_data.get("stairs_used", 0)),
        ("Highest Floor Reached", stats_data.get("highest_floor", 1))
    ])
    
    canvas.pack(side="left", fill="both", expand=True, padx=5, pady=5)
    scrollbar.pack(side="right", fill="y", pady=5)
    
    # Bind mousewheel to all child widgets
    def bind_mousewheel_to_tree(widget):
        def on_mousewheel(event):
            canvas.yview_scroll(int(-1*(event.delta/120)), "units")
        widget.bind("<MouseWheel>", on_mousewheel, add='+')
        for child in widget.winfo_children():
            bind_mousewheel_to_tree(child)
    bind_mousewheel_to_tree(scrollable_frame)


def _add_stats_section(game: 'DiceDungeonExplorer', parent, title, items):
    """Helper to add a statistics section"""
    section_frame = tk.Frame(parent, bg=game.current_colors["bg_dark"], relief=tk.RAISED, borderwidth=2)
    section_frame.pack(fill=tk.X, padx=10, pady=8)
    
    # Section title
    tk.Label(section_frame, text=title,
            font=('Arial', 12, 'bold'),
            bg=game.current_colors["bg_dark"],
            fg=game.current_colors["text_cyan"]).pack(anchor=tk.W, padx=10, pady=5)
    
    # Stats items
    for label, value in items:
        item_frame = tk.Frame(section_frame, bg=game.current_colors["bg_dark"])
        item_frame.pack(fill=tk.X, padx=15, pady=2)
        
        tk.Label(item_frame, text=label,
                font=('Arial', 10),
                bg=game.current_colors["bg_dark"],
                fg=game.current_colors["text_secondary"]).pack(side=tk.LEFT)
        
        tk.Label(item_frame, text=str(value),
                font=('Arial', 10, 'bold'),
                bg=game.current_colors["bg_dark"],
                fg=game.current_colors["text_gold"]).pack(side=tk.RIGHT)


def _populate_lore_tab(game: 'DiceDungeonExplorer', parent):
    """Populate the Lore Codex tab"""
    category_info = {
        "guards_journal": ("Guard Journals", "guards_journal_pages"),
        "quest_notice": ("Quest Notices", "quest_notices"),
        "scrawled_note": ("Scrawled Notes", "scrawled_notes"),
        "training_manual": ("Training Manuals", "training_manual_pages"),
        "pressed_page": ("Pressed Pages", "pressed_pages"),
        "surgeons_note": ("Surgeon's Notes", "surgeons_notes"),
        "puzzle_note": ("Puzzle Notes", "puzzle_notes"),
        "star_chart": ("Star Charts", "star_charts"),
        "map_scrap": ("Map Scraps", "map_scraps"),
        "old_letter": ("Old Letters", "old_letters"),
        "prayer_strip": ("Prayer Strips", "prayer_strips")
    }
    
    lore_by_type = {}
    for entry in game.lore_codex:
        lore_type = entry.get("type", "unknown")
        if lore_type not in lore_by_type:
            lore_by_type[lore_type] = []
        lore_by_type[lore_type].append(entry)
    
    for lore_type in lore_by_type:
        lore_by_type[lore_type].sort(key=lambda x: x.get("floor_found", 0))
    
    total_found = len(game.lore_codex)
    total_max = sum(game.lore_max_counts.values())
    
    header = tk.Frame(parent, bg=game.current_colors["bg_primary"])
    header.pack(fill=tk.X, padx=10, pady=10)
    tk.Label(header, text=f"Total Lore Discovered: {total_found}/{total_max}",
            font=('Arial', 12, 'bold'), bg=game.current_colors["bg_primary"],
            fg=game.current_colors["text_gold"]).pack()
    
    canvas = tk.Canvas(parent, bg=game.current_colors["bg_secondary"], highlightthickness=0)
    scrollbar = tk.Scrollbar(parent, orient="vertical", command=canvas.yview, width=10,
                            bg=game.current_colors["bg_secondary"], troughcolor=game.current_colors["bg_dark"])
    scrollable_frame = tk.Frame(canvas, bg=game.current_colors["bg_secondary"])
    
    scrollable_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
    
    def update_width(event=None):
        canvas.itemconfig(canvas_window, width=canvas.winfo_width()-10)
    
    canvas_window = canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
    canvas.bind("<Configure>", update_width)
    canvas.configure(yscrollcommand=scrollbar.set)
    game.setup_mousewheel_scrolling(canvas)
    
    # Track expanded state if not already present
    if not hasattr(game, '_lore_expanded'):
        game._lore_expanded = {}
    
    for lore_type, (display_name, json_key) in category_info.items():
        category_lore = lore_by_type.get(lore_type, [])
        count = len(category_lore)
        max_count = game.lore_max_counts.get(json_key, 0)
        
        category_frame = tk.Frame(scrollable_frame, bg=game.current_colors["bg_dark"], relief=tk.RAISED, borderwidth=2)
        category_frame.pack(fill=tk.X, padx=10, pady=5)
        
        header_frame = tk.Frame(category_frame, bg=game.current_colors["bg_dark"], cursor="hand2")
        header_frame.pack(fill=tk.X)
        
        expanded = game._lore_expanded.get(lore_type, False)
        arrow = "▼" if expanded else "►"
        arrow_label = tk.Label(header_frame, text=arrow, font=('Arial', 10),
                bg=game.current_colors["bg_dark"], fg=game.current_colors["text_cyan"], width=2)
        arrow_label.pack(side=tk.LEFT, padx=(5, 0))
        
        name_label = tk.Label(header_frame, text=display_name, font=('Arial', 11, 'bold'),
                bg=game.current_colors["bg_dark"], fg=game.current_colors["text_cyan"])
        name_label.pack(side=tk.LEFT, padx=5)
        
        count_color = game.current_colors["text_gold"] if count == max_count and count > 0 else game.current_colors["text_secondary"]
        count_label = tk.Label(header_frame, text=f"{count}/{max_count}", font=('Arial', 10, 'bold'),
                bg=game.current_colors["bg_dark"], fg=count_color)
        count_label.pack(side=tk.RIGHT, padx=10, pady=5)
        
        content_frame = tk.Frame(category_frame, bg=game.current_colors["bg_secondary"])
        if expanded:
            content_frame.pack(fill=tk.X, padx=5, pady=5)
        
        if count > 0:
            for entry in category_lore:
                entry_item = tk.Frame(content_frame, bg=game.current_colors["bg_dark"], relief=tk.GROOVE, borderwidth=1)
                entry_item.pack(fill=tk.X, padx=5, pady=2)
                
                entry_header = tk.Frame(entry_item, bg=game.current_colors["bg_dark"], cursor="hand2")
                entry_header.pack(fill=tk.X)
                
                # Show unique ID if available
                unique_id = entry.get('unique_id', '')
                id_text = f" #{unique_id}" if unique_id else ""
                
                title_text = f"{entry['title']}{id_text} (Floor {entry['floor_found']})"
                entry_title = tk.Label(entry_header, text=title_text, font=('Arial', 9),
                        bg=game.current_colors["bg_dark"], fg=game.current_colors["text_primary"])
                entry_title.pack(side=tk.LEFT, padx=8, pady=3)
                
                read_btn = tk.Button(entry_header, text="Read",
                        command=lambda e=entry: game.show_lore_entry_popup(e),
                        font=('Arial', 8, 'bold'), bg=game.current_colors["button_primary"],
                        fg='#000000', width=8, pady=1)
                read_btn.pack(side=tk.RIGHT, padx=5, pady=2)
        else:
            if expanded:
                tk.Label(content_frame, text="None discovered yet", font=('Arial', 9, 'italic'),
                        bg=game.current_colors["bg_secondary"],
                        fg=game.current_colors["text_secondary"]).pack(pady=5)
        
        def toggle_category(event=None, lt=lore_type, cf=content_frame, al=arrow_label, c=canvas):
            current = game._lore_expanded.get(lt, False)
            game._lore_expanded[lt] = not current
            
            if game._lore_expanded[lt]:
                al.config(text="▼")
                cf.pack(fill=tk.X, padx=5, pady=5)
            else:
                al.config(text="►")
                cf.pack_forget()
            
            c.update_idletasks()
            c.configure(scrollregion=c.bbox("all"))
        
        header_frame.bind("<Button-1>", toggle_category)
        arrow_label.bind("<Button-1>", toggle_category)
        name_label.bind("<Button-1>", toggle_category)
        count_label.bind("<Button-1>", toggle_category)
    
    canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=5, pady=5)
    scrollbar.pack(side=tk.RIGHT, fill=tk.Y, pady=5)
    
    # Bind mousewheel to all child widgets
    def bind_mousewheel_to_tree(widget):
        def on_mousewheel(event):
            canvas.yview_scroll(int(-1*(event.delta/120)), "units")
        widget.bind("<MouseWheel>", on_mousewheel, add='+')
        for child in widget.winfo_children():
            bind_mousewheel_to_tree(child)
    bind_mousewheel_to_tree(scrollable_frame)
