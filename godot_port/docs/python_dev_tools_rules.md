# Python Dev Tools Rules

Extracted from: `dice_dungeon_explorer.py` lines 327–331, 2040–2046, 7230–7277, 7998–8010, 8098+

## Activation
- Key sequence: `"1337"` typed in the pause menu activates dev mode
- Optional: `toggle_dev_mode()` button (gear icon) when dev mode is on

## Dev State
- `dev_mode`: bool — master toggle
- `dev_invincible`: god mode (player cannot die)

## Dev Config (defaults, lines 331–340)
```
enemy_hp_mult: 1.0
enemy_damage_mult: 1.0
player_damage_mult: 1.0
gold_drop_mult: 1.0
item_spawn_rate_mult: 1.0
shop_buy_price_mult: 1.0
shop_sell_price_mult: 1.0
durability_loss_mult: 1.0
enemy_dice_mult: 1.0
```

## Dev Tools Dialog
- `show_dev_tools()` (line 8098):
  - Enemies tab: spawn any enemy, search/sort
  - Other dev options

## Debug Logging
- `debug_logger` from `debug_logger.get_logger()` used in dice.py, combat.py
- Adventure log written to `saves/adventure_log{slot}.txt`
- Export: "Export Debug Log" in pause menu (dev mode only)

## Godot Implementation
- Godot-only dev feature (Python activation via "1337" is not needed)
- Dev menu accessible only in debug/editor builds (OS.is_debug_build())
- Hotkey: F10
- Must not ship enabled in release exports
- Features:
  - Show current seed + copy to clipboard
  - Start seeded run quickly
  - Spawn test combat (normal + miniboss)
  - Jump to floor N
