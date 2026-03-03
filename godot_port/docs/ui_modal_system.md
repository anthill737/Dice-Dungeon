# UI Modal System

Architecture reference for the popup overlay system.

## Components

| File | Role |
|------|------|
| `ui/scripts/menu_overlay_manager.gd` | Single authority for popup registration, sizing, stacking, close gating |
| `ui/scripts/popup_frame.gd` | Shared visual wrapper: dim background, gold-bordered panel, title bar, red ✕ close, content slot |
| `ui/scripts/explorer.gd` | In-game: registers 8 menus, wires signals, handles ESC |
| `ui/scripts/main_menu.gd` | Main menu: registers settings + save/load via same manager |

## Node Paths

```
Explorer/MenuOverlayManager          (CanvasLayer, layer 100)
  └─ PopupRoot                       (Control, FULL_RECT)
     ├─ <PopupFrame: inventory>      (Control, anchor-sized)
     │  ├─ DimBackground
     │  └─ PopupPanel
     │     ├─ Panel (visual bg)
     │     └─ VBoxContainer
     │        ├─ TitleBar / BtnPopupClose
     │        └─ ContentContainer / <content panel>
     ├─ <PopupFrame: save_load>
     └─ ...
```

## Registered Menus

| menu_key | Title | Size Profile | can_close |
|----------|-------|-------------|-----------|
| combat | ⚔ COMBAT ⚔ | combat | blocked during pending/active |
| inventory | 🎒 INVENTORY | inventory | always |
| store | 🏪 STORE | store | always |
| save_load | 💾 SAVE / LOAD | save_load | always |
| character_status | ⚙ CHARACTER STATUS | status | always |
| settings | ⚙ SETTINGS | settings | always |
| lore_codex | 📜 LORE CODEX | lore | always |
| pause | ☰ PAUSED | pause | always |

## Size Profiles (MenuOverlayManager.SIZE_PROFILES)

Mirrors Python `get_responsive_dialog_size(base_w, base_h, w_pct, h_pct)`:
`size = max(base, min(base * 1.5, viewport * pct))`

| Profile | base_w | base_h | width_pct | height_pct |
|---------|--------|--------|-----------|------------|
| pause | 350 | 300 | 0.35 | 0.45 |
| inventory | 450 | 500 | 0.45 | 0.75 |
| settings | 500 | 500 | 0.45 | 0.70 |
| store | 500 | 500 | 0.50 | 0.75 |
| combat | 700 | 600 | 0.65 | 0.85 |
| status | 650 | 600 | 0.65 | 0.85 |
| lore | 650 | 600 | 0.65 | 0.85 |
| save_load | 700 | 550 | 0.70 | 0.80 |

## ESC Behavior

1. If any popup is open → `close_top_menu()` (LIFO, respects can_close)
2. If no popup is open → open pause menu
3. Both `ui_cancel` (Q) and `open_menu` (Escape) trigger this

## Close Rules

- PopupFrame provides a red ✕ button → emits `close_requested`
- Manager checks `can_close(menu_key)` before closing
- Combat popup: blocked while `is_pending_choice()` or `is_combat_active()`
- All other popups: always closable

## Pause Menu Submenu Flow

Pause → Save/Load: closes pause, opens save_load popup
Pause → Settings: closes pause, opens settings popup
Pause → Quit: shows inline confirm, then `change_scene_to_file(MainMenu)`
