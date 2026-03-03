# Architecture Refactor — Summary

## What moved / was created

| Action   | Path                                    | Purpose                                       |
|----------|-----------------------------------------|-----------------------------------------------|
| Created  | `game/services/`                        | New services layer directory                   |
| Created  | `game/services/game_context.gd`         | Scene-scoped service registry (GameContext)     |
| Created  | `game/services/content_manager.gd`      | Centralised JSON data loading (ContentManager) |
| Created  | `game/services/save_load_service.gd`    | Save/load coordination (SaveLoadService)       |
| Created  | `game/services/session_service.gd`      | Session lifecycle (SessionService)             |
| Created  | `game/services/adventure_log_service.gd`| Append-only adventure log (AdventureLogService)|
| Created  | `game/app/`                             | Future app/composition layer directory         |
| Modified | `ui/scripts/game_session.gd`            | Uses ContentManager for data loading           |
| Modified | `ui/scripts/explorer.gd`                | Creates GameContext, wires services            |
| Modified | `ui/scripts/main_menu.gd`               | Creates GameContext                            |
| Created  | `tests/test_game_context.gd`            | 9 tests for GameContext                        |
| Created  | `tests/test_content_manager.gd`         | 18 tests for ContentManager                   |
| Created  | `tests/test_save_load_service.gd`       | 9 tests for SaveLoadService                    |
| Created  | `tests/test_session_service.gd`         | 3 tests for SessionService                     |
| Created  | `tests/test_adventure_log_service.gd`   | 6 tests for AdventureLogService                |
| Created  | `docs/architecture_modules.md`          | Layering rules and service catalogue           |

## New layer mapping

```
App/Composition     explorer.gd, main_menu.gd  — create GameContext, inject
Services            game/services/*             — 6 services (see architecture_modules.md)
UI                  ui/scripts/*, ui/scenes/*   — thin adapters, render state
Core                game/core/**                — pure engines, models, data loaders, RNG
```

## Test status

- 342 tests across 31 scripts — **all passing** headlessly.
- 45 new tests added for the 5 new services.

## Remaining technical debt (intentionally deferred)

| Item | Reason deferred |
|------|----------------|
| UI panels still reference `GameSession` autoload directly | Migrating every panel to `GameContext` services in a single PR risks touching too many files and potentially altering RNG/parity outcomes. Panels should be migrated incrementally. |
| `GameSession` remains an autoload singleton | Removing it requires every panel and test that references `GameSession` to be updated. The `GameContext` facade is in place for new code to use; old code can migrate over time. |
| `game/app/` directory is empty | Explorer root and MainMenu conceptually belong in the app layer but live in `ui/scripts/` to avoid path-breaking moves. Future work can relocate them. |
| Individual data loaders (`RoomsData`, `ItemsData`, …) still exist as standalone classes | They are used internally by `ContentManager` and directly by existing tests. Inlining them into `ContentManager` would break 32 existing data-loader tests. |
| `save_load_panel.gd` still accesses `GameSession` for saves_dir and engine wiring | Should be migrated to use `GameContext.save_load` in a follow-up. |
| `MenuOverlayManager` does not depend on `GameContext` | It receives a reference via `GameContext.set_menus()` but is not injected in the other direction. This is acceptable since the overlay manager is a pure UI concern. |
| No class-per-type consolidation needed | The codebase already avoids manager-per-type classes — there is no `EnemyManager`, `ItemManager`, etc. `ContentManager` now formalises this pattern. |
