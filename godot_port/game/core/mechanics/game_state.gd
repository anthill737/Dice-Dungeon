class_name GameState
extends RefCounted
## Minimal player/game state used by MechanicsEngine.
##
## Mirrors the attributes Python's PlayerAdapter expects on the game object.
## Game systems mutate this; MechanicsEngine reads and writes it.

var health: int = 50
var max_health: int = 50
var gold: int = 0
var total_gold_earned: int = 0
var multiplier: float = 1.0
var damage_bonus: int = 0
var crit_chance: float = 0.1
var reroll_bonus: int = 0
var temp_shield: int = 0
var shop_discount: float = 0.0
var armor: int = 0

var inventory: Array = []
var max_inventory: int = 20
var ground_items: Array = []

## Equipment slots: weapon, armor, accessory, backpack
var equipped_items: Dictionary = {
	"weapon": "",
	"armor": "",
	"accessory": "",
	"backpack": "",
}

## Durability per equipment item name -> current durability
var equipment_durability: Dictionary = {}

## Floor level at which each equipment was acquired (for scaling)
var equipment_floor_level: Dictionary = {}

## Combat temp buffs (cleared after combat)
var temp_combat_damage: int = 0
var temp_combat_crit: float = 0.0
var temp_combat_rerolls: int = 0

## Floor number (needed for store pricing / equipment scaling)
var floor: int = 1

## Store tracking
var purchased_upgrades_this_floor: Dictionary = {}

## Dice
var num_dice: int = 3
var max_dice: int = 5

## Stats tracking
var stats: Dictionary = {
	"items_used": 0,
	"potions_used": 0,
	"items_found": 0,
	"items_sold": 0,
	"items_purchased": 0,
	"gold_found": 0,
	"gold_spent": 0,
	"containers_searched": 0,
}

## Combat state
var in_combat: bool = false

var flags: Dictionary = {
	"disarm_token": 0,
	"escape_token": 0,
	"statuses": [],
}

## Temp effects: key -> {"delta": number, "duration": "combat"|"floor"}
var temp_effects: Dictionary = {}

## Difficulty multipliers applied from SettingsManager at run start
var difficulty: String = "Normal"
var difficulty_mults: Dictionary = {
	"player_damage_mult": 1.0,
	"player_damage_taken_mult": 1.0,
	"enemy_health_mult": 1.0,
	"enemy_damage_mult": 1.0,
	"loot_chance_mult": 1.0,
	"heal_mult": 1.0,
}

## Lore state — mirrors Python game.lore_codex / lore_item_assignments / used_lore_entries
var lore_codex: Array = []
var lore_item_assignments: Dictionary = {}
var used_lore_entries: Dictionary = {}


func reset() -> void:
	health = 50
	max_health = 50
	gold = 0
	total_gold_earned = 0
	multiplier = 1.0
	damage_bonus = 0
	crit_chance = 0.1
	reroll_bonus = 0
	temp_shield = 0
	shop_discount = 0.0
	armor = 0
	inventory = []
	max_inventory = 20
	ground_items = []
	equipped_items = {"weapon": "", "armor": "", "accessory": "", "backpack": ""}
	equipment_durability = {}
	equipment_floor_level = {}
	temp_combat_damage = 0
	temp_combat_crit = 0.0
	temp_combat_rerolls = 0
	floor = 1
	purchased_upgrades_this_floor = {}
	num_dice = 3
	max_dice = 5
	stats = {
		"items_used": 0,
		"potions_used": 0,
		"items_found": 0,
		"items_sold": 0,
		"items_purchased": 0,
		"gold_found": 0,
		"gold_spent": 0,
		"containers_searched": 0,
	}
	in_combat = false
	flags = {"disarm_token": 0, "escape_token": 0, "statuses": []}
	temp_effects = {}
	difficulty = "Normal"
	difficulty_mults = {
		"player_damage_mult": 1.0,
		"player_damage_taken_mult": 1.0,
		"enemy_health_mult": 1.0,
		"enemy_damage_mult": 1.0,
		"loot_chance_mult": 1.0,
		"heal_mult": 1.0,
	}
	lore_codex = []
	lore_item_assignments = {}
	used_lore_entries = {}
