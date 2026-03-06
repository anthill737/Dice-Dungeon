# Dice Dungeon – Architecture Modules

## Layering Rules

The codebase is organised into four layers.  Dependencies flow
**downward only**: UI → Services → Core → (data files).

```
┌─────────────────────────────────────────────┐
│  App / Composition  (Explorer root, MainMenu) │
│  Creates GameContext, injects into UI panels   │
├─────────────────────────────────────────────┤
│  UI  (panels, overlays, theme)                 │
│  Thin adapters: gather input, call services,   │
│  render state.  No direct file I/O.            │
├─────────────────────────────────────────────┤
│  Services  (GameContext, ContentManager, …)    │
│  Coordinate core engines + persistence.        │
│  Emit signals for UI to subscribe to.          │
├─────────────────────────────────────────────┤
│  Core  (engines, models, data loaders, RNG)    │
│  Pure / deterministic.  No get_node(), no      │
│  Control/Node/SceneTree, no direct file I/O    │
│  (except data loaders via res:// paths).       │
└─────────────────────────────────────────────┘
```

### Layer paths

| Layer       | Directory                   | Extends             |
|-------------|-----------------------------|----------------------|
| Core        | `game/core/**`              | `RefCounted`         |
| Services    | `game/services/**`          | `RefCounted` or `Node` |
| UI          | `ui/scripts/**`, `ui/scenes/**` | `Control` / `CanvasLayer` |
| App         | `game/app/` (future), currently `ui/scripts/explorer.gd`, `ui/scripts/main_menu.gd` | `Control` |

---

## Services and Responsibilities

There are **six** coordination services.  No manager-per-type classes
(no EnemyManager, ItemManager, WeaponManager, etc.).

### 1. GameContext (`game/services/game_context.gd`)

Scene-scoped service registry.  Created by Explorer root and MainMenu.

| Property     | Type                   | Notes                        |
|--------------|------------------------|------------------------------|
| `content`    | `ContentManager`       | Owned, created in _init      |
| `save_load`  | `SaveLoadService`      | Owned, created in _init      |
| `session`    | `SessionService`       | Owned, needs GameSession ref |
| `log`        | `AdventureLogService`  | Owned, created in _init      |
| `menus`      | `MenuOverlayManager`   | Set after overlay setup      |
| `settings`   | `Node`                 | SettingsManager autoload ref |

### 2. ContentManager (`game/services/content_manager.gd`)

Loads and caches every JSON DB from `res://data/` via the existing
per-format loader classes (`RoomsData`, `ItemsData`, …).

Key methods:
- `load_all() -> bool`
- `get_room_templates() -> Array`
- `get_item_def(id) -> Dictionary`
- `get_enemy_def(name) -> Dictionary`
- `get_lore_entry(category) -> Array`
- `get_world_lore() -> Dictionary`
- `get_container_def(name) -> Dictionary`

### 3. SaveLoadService (`game/services/save_load_service.gd`)

Wraps `SaveEngine` plus saves-directory management.

Key methods:
- `save_to_slot(game, floor_st, slot, save_name) -> bool`
- `load_from_slot(slot, game, floor_st) -> bool`
- `delete_slot(slot) -> bool`
- `rename_slot(slot, new_name) -> bool`
- `list_slots() -> Array`

Signals: `saved`, `loaded`, `deleted`, `renamed`.

### 4. SessionService (`game/services/session_service.gd`)

Session lifecycle with no UI.

Key methods:
- `start_run()` — delegates to `GameSession.start_new_game()`
- `end_run()` — nulls combat, clears pending state
- `quit_to_main_menu()` — calls `end_run()`, emits `quit_requested`

Signals: `run_started`, `run_ended`, `quit_requested`.

### 5. AdventureLogService (`game/services/adventure_log_service.gd`)

Append-only log with signal.

Key methods:
- `append(entry)`
- `clear()`
- `get_entries() -> Array`

Signal: `entry_added(entry)`.

### 6. MenuOverlayManager (`ui/scripts/menu_overlay_manager.gd`)

Already exists.  Accessed via `GameContext.menus`.  Owns popup stack
and ESC gating.  No deep scene coupling.

---

## Dependency Wiring

```
Explorer._ready()
  ├── ctx = GameContext.new()          # creates ContentManager, SaveLoadService,
  │                                     #   SessionService, AdventureLogService
  ├── _setup_overlay_manager()
  ├── ctx.set_menus(overlay_manager)   # inject overlay ref
  ├── ctx.session.quit_requested → _on_quit_requested
  └── GameSession.log_message → ctx.log.append   (bridge)
```

GameSession remains an autoload for now.  It holds the core engines and
emits `state_changed`, `combat_started`, `combat_ended`, `log_message`.
UI panels still read from GameSession directly; future work will migrate
them to use `GameContext` services exclusively.

SettingsManager remains an autoload (truly global: keybindings, display prefs).

---

## Anti-patterns to Avoid

1. **Manager-per-type** — Do NOT create `EnemyManager`, `ItemManager`,
   `ConsumableManager`, `WeaponManager`, `LoreManager`.  Use
   `ContentManager` with typed getters instead.

2. **Autoload-everything** — Only `SettingsManager` and `GameSession`
   are autoloads.  `GameContext` is scene-scoped.

3. **UI-in-core** — Core classes must never call `get_node()`, reference
   `Control`/`Node`/`SceneTree`, or trigger scene transitions.

4. **Deep scene traversal** — UI panels should call services via
   `GameContext`, not walk the scene tree with chains of `get_parent()`
   or `get_node("../../..")`.

5. **Scattered loaders** — All JSON loading goes through
   `ContentManager`.  Do not add new standalone `*Data` loader classes.
