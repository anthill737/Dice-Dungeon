class_name TooltipFormatter
extends RefCounted
## Centralized tooltip text formatting for items.
## No gameplay logic — pure display formatting.
## Used by inventory panel, ground items panel, store panel, etc.


## Format an item tooltip string from an item definition dictionary.
## Omits "Type:" per design requirement. Includes effect summaries.
static func format(item_name: String, item_def: Dictionary) -> String:
	var lines: PackedStringArray = [item_name]

	var desc: String = item_def.get("desc", "")
	if not desc.is_empty():
		lines.append(desc)

	var effects := _build_effect_summary(item_def)
	if not effects.is_empty():
		lines.append(effects)

	return "\n".join(lines)


## Build a one-line effect summary from item_def mechanical properties.
static func _build_effect_summary(item_def: Dictionary) -> String:
	var parts: PackedStringArray = []
	if item_def.has("heal"):
		parts.append("Heals %s HP" % str(item_def["heal"]))
	if item_def.has("damage_bonus"):
		parts.append("+%s Damage" % str(item_def["damage_bonus"]))
	if item_def.has("crit_bonus"):
		parts.append("+%s%% Crit" % str(int(float(item_def["crit_bonus"]) * 100)))
	if item_def.has("shield"):
		parts.append("+%s Shield" % str(item_def["shield"]))
	if item_def.has("extra_rolls"):
		parts.append("+%s Rerolls" % str(item_def["extra_rolls"]))
	if item_def.has("max_hp_bonus"):
		parts.append("+%s Max HP" % str(item_def["max_hp_bonus"]))
	if item_def.has("armor_bonus"):
		parts.append("+%s Armor" % str(item_def["armor_bonus"]))
	if item_def.has("inventory_bonus"):
		parts.append("+%s Slots" % str(item_def["inventory_bonus"]))
	if not parts.is_empty():
		return ", ".join(parts)
	return ""
