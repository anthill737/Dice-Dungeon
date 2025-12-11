# Dice Dungeon Explorer

A roguelike dungeon crawler where you roll dice to fight enemies, explore procedurally generated dungeons, and collect loot!

## Features

- **Dice-Based Combat**: Roll dice to attack enemies with strategic locking and re-rolling
- **Procedurally Generated Dungeons**: Each floor is unique with varied room types
- **Character Progression**: Level up, find equipment, and unlock abilities
- **Multiple Enemy Types**: Fight 288 different enemies with unique sprites
- **Boss Battles**: Epic encounters with special enemies
- **Lore System**: Discover the story through found lore items
- **Equipment System**: Find and upgrade weapons, armor, and accessories
- **Item Management**: Potions, keys, and special items
- **Save System**: Multiple save slots to track your progress
- **Customizable Keybindings**: Configure controls to your preference
- **Theme System**: Multiple color themes (Light/Dark modes)
- **Difficulty Settings**: Easy, Normal, Hard, and Nightmare modes

## Installation

### Requirements
- Python 3.11 or higher
- Tkinter (usually included with Python)
- PIL/Pillow for image handling

### Setup
```bash
# Clone the repository
git clone https://github.com/yourusername/dice-dungeon.git
cd dice-dungeon

# Install dependencies
pip install pillow

# Run the game
python dice_dungeon_launcher.py
```

## How to Play

### Controls
- **Arrow Keys**: Navigate menus and move through rooms
- **Space/Enter**: Confirm actions, roll dice
- **R**: Re-roll unlocked dice
- **L**: Lock/unlock individual dice
- **A**: Attack enemy
- **I**: Open inventory
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

## Project Structure

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
│   ├── content_loader.py       # Dynamic content loading
│   ├── enemy_data.py           # Enemy definitions
│   └── room_data.py            # Room templates
├── assets/                      # Game assets
│   └── enemy_sprites/          # Enemy sprite images
└── logs/                        # Debug logs (generated)
```

## Modding

See [MODDING_GUIDE.md](MODDING_GUIDE.md) for information on:
- Adding new enemies
- Creating custom rooms
- Modifying game balance
- Adding new items

## Development

### Debug Mode
Enable debug logging by setting the debug flag in the launcher:
```python
DEBUG_MODE = True
```

See [DEBUG_LOGGING_GUIDE.md](DEBUG_LOGGING_GUIDE.md) for more details.

### Lore System
The game includes a dynamic lore system. See [LORE_SYSTEM_README.md](LORE_SYSTEM_README.md) for implementation details.

### Settings System
Configuration and settings management is documented in [SETTINGS_SYSTEM_GUIDE.md](SETTINGS_SYSTEM_GUIDE.md).

## Credits

- Game Design & Programming: [Your Name]
- Enemy Sprites: Generated with AI assistance
- Built with Python & Tkinter

## License

[Add your chosen license here - MIT, GPL, etc.]

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and updates.

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## Support

If you encounter any issues or have questions:
1. Check the documentation files
2. Review existing issues on GitHub
3. Open a new issue with details about your problem
