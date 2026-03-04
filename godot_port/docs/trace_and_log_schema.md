# Trace and Log Schema

## Log Entry Schema

Each adventure log entry is a `Dictionary` with these fields:

| Field       | Type   | Required | Description                                      |
|-------------|--------|----------|--------------------------------------------------|
| `text`      | String | Yes      | The human-readable log message                   |
| `tag`       | String | Yes      | Color/style hint: `system`, `enemy`, `loot`, `success`, `crit` |
| `category`  | String | Yes      | Standardized category (see below)                |
| `source`    | String | Yes      | Origin system: `exploration`, `combat`, `store`, `system` |
| `action_id` | int    | Yes      | Monotonically increasing per-entry counter       |

### Valid Categories

```
ROOM, COMBAT, SYSTEM, DISCOVERY, LOOT, INTERACTION, HAZARD, STORE
```

Invalid or empty categories are normalized to `SYSTEM`.

---

## Trace Event Schema

Each trace event is a `Dictionary`:

| Field     | Type       | Description                                  |
|-----------|------------|----------------------------------------------|
| `t_ms`    | int        | Milliseconds since run start                 |
| `type`    | String     | Event type identifier                        |
| `floor`   | int        | Current floor number                         |
| `coord`   | Array[int] | `[x, y]` position on floor                  |
| `payload` | Dictionary | Event-specific data                          |
| `snapshot` | Dictionary | (milestone events only) State snapshot       |

### Milestone Events

These events include a `snapshot` field with a lightweight state summary:

- `run_started`
- `floor_started`
- `room_entered`
- `combat_started`
- `combat_ended`
- `saved`
- `loaded`

### Snapshot Fields

| Field              | Type   | Description                          |
|--------------------|--------|--------------------------------------|
| `floor`            | int    | Current floor                        |
| `coord`            | Array  | `[x, y]` (if floor state available)  |
| `hp`               | int    | Current health                       |
| `max_hp`           | int    | Maximum health                       |
| `gold`             | int    | Current gold                         |
| `inventory_count`  | int    | Number of inventory items            |
| `equipped_summary` | String | Comma-separated `slot:item` pairs    |
| `room_name`        | String | Current room name (when available)   |

---

## Copy Log Header

When the user clicks "Copy Log", a stable header is prepended:

```
=== Dice Dungeon — Adventure Log ===
Seed: <number>
RNG Mode: default|deterministic
Floor: <n>
Room: <room name>
Action ID: <current action id>
Build: <build_version>
Content Version: <content_version>
Settings Fingerprint: <settings_fingerprint>
====================================
```

---

## F4 Export JSON Top-Level Fields

| Field                  | Type     | Description                              |
|------------------------|----------|------------------------------------------|
| `run_id`               | String   | Unique run identifier                    |
| `start_time_utc`       | String   | ISO timestamp                            |
| `seed`                 | int      | RNG seed (always numeric)                |
| `run_seed`             | int      | Alias for seed                           |
| `rng_mode`             | String   | `"default"` or `"deterministic"`         |
| `rng_type`             | String   | RNG class name                           |
| `game_version`         | String   | Git SHA                                  |
| `build_version`        | String   | Git short SHA at runtime                 |
| `build_time_utc`       | String   | Build timestamp                          |
| `content_version`      | String   | Hash of data JSON files                  |
| `settings_fingerprint` | String   | Hash of relevant settings                |
| `difficulty`           | String   | Difficulty level                         |
| `event_count`          | int      | Number of trace events                   |
| `events`               | Array    | Trace events                             |
| `adventure_log`        | Array    | Log entries with metadata                |
| `adventure_log_count`  | int      | Number of log entries                    |

### Per-Entry Fields in `adventure_log`

| Field        | Type   | Description                     |
|--------------|--------|---------------------------------|
| `index`      | int    | Entry index                     |
| `text`       | String | Log message                     |
| `event_type` | String | Tag (color hint)                |
| `category`   | String | Standardized category           |
| `source`     | String | Origin system                   |
| `action_id`  | int    | Monotonic entry counter         |
