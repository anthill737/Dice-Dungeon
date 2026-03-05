class_name CombatUIPacing
extends RefCounted
## UI-only pacing helper for combat animations.
##
## Provides timing multipliers for combat UI effects based on the
## combat_pacing setting. Never affects simulation order or RNG.

enum Preset { INSTANT, FAST, NORMAL, SLOW }

const PRESET_NAMES := ["Instant", "Fast", "Normal", "Slow"]

const PRESET_MAP := {
	"Instant": Preset.INSTANT,
	"Fast": Preset.FAST,
	"Normal": Preset.NORMAL,
	"Slow": Preset.SLOW,
}

const DICE_ROLL_INTERVAL := {
	Preset.INSTANT: 0.0,
	Preset.FAST: 0.015,
	Preset.NORMAL: 0.025,
	Preset.SLOW: 0.04,
}

const DICE_ROLL_FRAMES := {
	Preset.INSTANT: 0,
	Preset.FAST: 4,
	Preset.NORMAL: 8,
	Preset.SLOW: 12,
}

const DAMAGE_FLOAT_DURATION := {
	Preset.INSTANT: 0.1,
	Preset.FAST: 0.4,
	Preset.NORMAL: 0.8,
	Preset.SLOW: 1.2,
}

const HIT_FLASH_DURATION := {
	Preset.INSTANT: 0.05,
	Preset.FAST: 0.25,
	Preset.NORMAL: 0.5,
	Preset.SLOW: 0.8,
}

const LOG_REVEAL_DELAY_MS := {
	Preset.INSTANT: 0,
	Preset.FAST: 30,
	Preset.NORMAL: 60,
	Preset.SLOW: 120,
}


static func get_preset() -> Preset:
	var sm = Engine.get_singleton("SettingsManager") if Engine.has_singleton("SettingsManager") else null
	if sm == null:
		sm = Engine.get_main_loop().root.get_node_or_null("/root/SettingsManager") if Engine.get_main_loop() else null
	if sm != null and "combat_pacing" in sm:
		return PRESET_MAP.get(sm.combat_pacing, Preset.NORMAL)
	return Preset.NORMAL


static func dice_roll_interval() -> float:
	return DICE_ROLL_INTERVAL[get_preset()]


static func dice_roll_frames() -> int:
	return DICE_ROLL_FRAMES[get_preset()]


static func damage_float_duration() -> float:
	return DAMAGE_FLOAT_DURATION[get_preset()]


static func hit_flash_duration() -> float:
	return HIT_FLASH_DURATION[get_preset()]


static func log_reveal_delay_ms() -> int:
	return LOG_REVEAL_DELAY_MS[get_preset()]
