# 🎲 Dice Dungeon

A roguelike dungeon crawler where you roll dice to fight enemies, explore procedurally generated dungeons, and collect loot!

![GitHub last commit](https://img.shields.io/github/last-commit/anthill737/dice-dungeon)
![Python Version](https://img.shields.io/badge/python-3.11+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

---

## 📥 Installation

### Windows (Easy — No Python Required)

1. Go to the [**Latest Release**](https://github.com/anthill737/Dice-Dungeon/releases/latest)
2. Download **`DiceDungeon.exe`** from the **Assets** section at the bottom
3. Move it anywhere you like (Desktop, Games folder, etc.)
4. Double-click **`DiceDungeon.exe`** to play!

> **Windows SmartScreen warning?** Click **"More info"** → **"Run anyway"**. This happens because the EXE isn't code-signed — it's safe.

### Mac / Linux (Requires Python 3.11+)

```bash
git clone https://github.com/anthill737/dice-dungeon.git
cd dice-dungeon
chmod +x scripts/setup.sh
./scripts/setup.sh
```

**That's it!** The game runs directly — no installer or Python needed on Windows.

### Updating the Game

To update, just download the new `DiceDungeon.exe` from the [Releases page](https://github.com/anthill737/Dice-Dungeon/releases) and replace the old one. Your save files are stored in `%APPDATA%/DiceDungeon` and will carry over automatically.

---

## 🎮 Features

- **Dice-Based Combat**: Roll dice to attack enemies with strategic locking and re-rolling
- **Procedurally Generated Dungeons**: Each floor is unique with varied room types
- **Character Progression**: Find equipment, and unlock abilities
- **Multiple Enemy Types**: Fight 288 different enemies with unique sprites
- **Boss Battles**: Epic encounters with special enemies
- **Lore System**: Discover the story through found lore items
- **Equipment System**: Find and upgrade weapons, armor, and accessories
- **Item Management**: Potions, keys, and special items
- **Save System**: Multiple save slots to track your progress
- **Customizable Keybindings**: Configure controls to your preference
- **Difficulty Settings**: Easy, Normal, Hard, and Nightmare modes

## 🎮 How to Play

### Controls
- **Arrow Keys or WASD**: Navigate menus and move through rooms
- **Space/Enter**: Confirm actions, roll dice
- **Tab**: Open inventory
- **ESC**: Open menu/close dialogs

### Gameplay Loop
1. Roll dice to generate attack damage
2. Lock dice you want to keep
3. Re-roll remaining dice 
4. Attack enemies after your final roll or once you're happy with your dice roll.
5. Explore rooms to find treasure, shops, and stairs to descend deeper into the dungeon for better rewards

### Combat Tips
- Higher dice rolls = more damage
- Lock high-value dice before re-rolling
- Use potions strategically
- Some enemies have special abilities
- Equipment provides bonuses to damage and defense

## 📁 Project Structure

```
dice-dungeon/
├── dice_dungeon_launcher.py    # Game launcher
├── dice_dungeon_explorer.py    # Main game file
├── debug_logger.py              # Debug logging system
├── explorer/                    # Core game modules
│   ├── combat.py               # Combat system
│   ├── dice.py                 # Dice mechanics
│   ├── inventory_display.py    # Inventory UI
│   ├── inventory_pickup.py     # Item pickup system
│   ├── lore.py                 # Lore system
│   └── store.py                # Shop system
├── dice_dungeon_content/       # Content engine
│   └── data/                   # Game data (enemies, items, rooms)
├── assets/                      # Game assets
│   └── sprites/                # Enemy sprite images
└── saves/                       # Save files
```

## 🆘 Troubleshooting

**Windows SmartScreen blocks the EXE**
- Click "More info" → "Run anyway" — this happens because the EXE isn't code-signed

**Game won't launch / crashes immediately**
- Make sure you downloaded the latest version from [Releases](https://github.com/anthill737/Dice-Dungeon/releases/latest)
- Try right-clicking → "Run as administrator"

**"No module named 'PIL'" (Mac/Linux only)**
- Run: `pip install pillow`

**Saves not appearing after update?**
- Save files are stored in `%APPDATA%/DiceDungeon/saves/` and should persist across updates automatically
- If you previously ran an older version, saves will be migrated on first launch

## 📝 Credits

- Game Design & Programming: Anthony & AI
- Enemy Sprites: Generated with AI assistance
- Built with Python & Tkinter

## 📄 License

All rights reserved.

## 📜 Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and updates.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.
