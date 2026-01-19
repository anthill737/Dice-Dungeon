# 🎲 Dice Dungeon

A roguelike dungeon crawler where you roll dice to fight enemies, explore procedurally generated dungeons, and collect loot!

![GitHub last commit](https://img.shields.io/github/last-commit/anthill737/dice-dungeon)
![Python Version](https://img.shields.io/badge/python-3.11+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

---

## 📥 Installation

### Windows

1. [Download this repository](https://github.com/anthill737/dice-dungeon/archive/refs/heads/main.zip)
2. Extract the ZIP file
3. Double-click **`scripts/SETUP.bat`**
4. A graphical installer opens - choose where to install
5. Click "Install"
6. Launch 

**That's it** The installer copies the pre-built DiceDungeon.exe to your chosen location and creates shortcuts.

### Mac / Linux

```bash
git clone https://github.com/anthill737/dice-dungeon.git
cd dice-dungeon
chmod +x scripts/setup.sh
./scripts/setup.sh
```

**That's it** The installer:
- Copies the pre-built DiceDungeon.exe to your chosen location
- Takes about 10 seconds
- The downloaded folder can be deleted after installation

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
3. Re-roll remaining dice (costs 1 stamina)
4. Attack enemies with your final roll
5. Explore rooms to find treasure, shops, and stairs
6. Descend deeper into the dungeon for better rewards

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
Installer won't run / "Python is not recognized"**
- The installer should handle Python installation automatically
- If it fails, you can manually install Python from https://www.python.org/downloads/
- Make sure to check "Add Python to PATH" during installation
- Then run scripts/SETUP.bat again
- During installation, check "Add Python to PATH"

**"No module named 'PIL'"**
- The installer should handle this, but you can manually run: `pip install pillow`

**Game won't launch**
- Make sure the installation completed successfully
- Try running `Launch Dice Dungeon.bat` from your install folder
- Verify Python 3.11+: `python --version`
anthill737
**Need more help?**
- [Open an issue on GitHub](https://github.com/yourusername/dice-dungeon/issues)

## 📝 Credits

- Game Design & Programming: [Your Name]
- Enemy Sprites: Generated with AI assistance
- Built with Python & Tkinter

## 📄 License

All rights reserved.

## 📜 Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and updates.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.
