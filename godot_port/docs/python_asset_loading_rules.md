# Python Asset Loading Rules

Authoritative reference for how the Python game loads and resolves enemy sprites
and item icons. The Godot port must replicate these rules exactly.

---

## 1. Enemy Sprites

### Source

Sprites live on the filesystem at:
```
assets/sprites/enemies/<folder_name>/rotations/south.png
```

### Resolution Rule

1. **No sprite field in enemy_types.json.** Enemy type data contains only
   behavior (abilities, split rules). Sprite paths are derived from the
   filesystem, not from data files.

2. **Folder scanning:** `load_enemy_sprites()` in `dice_dungeon_explorer.py`
   scans all subdirectories under `assets/sprites/enemies/`.

3. **Folder name → enemy name conversion:**
   ```python
   enemy_name = ' '.join(word.capitalize() for word in folder_name.split('_'))
   enemy_name = re.sub(r'\bCharmers\b', "Charmer's", enemy_name)
   enemy_name = re.sub(r'\bOf\b', 'of', enemy_name)
   ```
   Examples:
   - `acid_hydra` → `Acid Hydra`
   - `charmers_serpent` → `Charmer's Serpent`
   - `jury_of_crows` → `Jury of Crows`

4. **Reverse (enemy name → folder slug):** The Godot resolver must also support
   looking up by enemy name. The slug is computed by:
   - Lowercasing
   - Replacing `'` with empty string
   - Replacing non-alphanumeric characters with `_`
   - Stripping leading/trailing `_`

5. **Image selection priority:**
   - `rotations/south.png` (preferred)
   - `rotations/west.png` (fallback)
   - `rotations/east.png` (fallback)
   - `rotations/north.png` (fallback)

6. **Fallback when no sprite:** Display placeholder text `"Enemy\nSprite"`.
   The UI still functions normally — enemy name and HP are shown in text.

### Display

- Sprites are resized to `max(48, int(110 * scale_factor))` pixels square.
- Displayed in a dedicated sprite area next to enemy HP/info during combat.
- The current target enemy's sprite is shown.

---

## 2. Item Icons

### Source

Icons live on the filesystem at:
```
assets/icons/items/<slugified_name>.png
```

### Resolution Rule

1. **No icon field in items_definitions.json.** Item data contains only type,
   stats, and description. Icon paths are derived from the item name.

2. **Slugify function** (`explorer/item_icons.py`):
   ```python
   def slugify(name: str) -> str:
       s = name.lower().strip()
       s = re.sub(r"[''']", "", s)
       s = re.sub(r"[^a-z0-9]+", "_", s)
       return s.strip("_")
   ```
   Examples:
   - `"Health Potion"` → `health_potion`
   - `"Greater Health Potion"` → `greater_health_potion`
   - `"Charmer's Amulet"` → `charmers_amulet`

3. **Path resolution** (`get_item_icon_path()`):
   ```python
   specific = icons_dir / f"{slug}.png"
   if specific.exists():
       return specific
   fallback = icons_dir / "unknown.png"
   return fallback
   ```

4. **Fallback:** If the specific icon file doesn't exist, use `unknown.png`.
   If `unknown.png` also doesn't exist, return the path anyway (callers check
   existence and show no icon if missing).

### Display

- Icons are resized to `max(36, int(42 * scale_factor))` pixels square.
- Shown next to item names in:
  - Inventory panel (item list + tooltip)
  - Store panel (buy/sell lists)
  - Equipment display
  - Container/pickup dialogs
- Results are cached by `(slug, size)` tuple.

---

## 3. Asset Directory Layout

```
assets/
├── icons/
│   └── items/
│       ├── health_potion.png
│       ├── iron_sword.png
│       ├── unknown.png          ← fallback icon
│       └── ...                  (231 icons total)
├── sprites/
│   └── enemies/
│       ├── acid_hydra/
│       │   └── rotations/
│       │       └── south.png
│       ├── rat_swarm/
│       │   └── rotations/
│       │       └── south.png
│       └── ...                  (288 enemy folders)
└── DD Icon.png, DD Logo.png
```

---

## 4. Key Differences from Godot Considerations

- Python uses PIL `Image.open()` + `ImageTk.PhotoImage` for display.
- Godot equivalent: `Image.load_from_file()` + `ImageTexture.create_from_image()`.
- Assets are outside `godot_port/` at `../assets/` (repo root).
- The resolver must handle missing assets gracefully (no crash).
- Caching is recommended (same as Python's `lru_cache` and dict cache).
