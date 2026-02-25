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

var inventory: Array = []
var ground_items: Array = []

var flags: Dictionary = {
	"disarm_token": 0,
	"escape_token": 0,
	"statuses": [],
}

## Temp effects: key -> {"delta": number, "duration": "combat"|"floor"}
var temp_effects: Dictionary = {}


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
	inventory = []
	ground_items = []
	flags = {"disarm_token": 0, "escape_token": 0, "statuses": []}
	temp_effects = {}
