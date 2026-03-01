class_name DiceRoller
extends RefCounted
## Pure dice mechanics: roll, lock, reroll, combo scoring, damage calc.
## No UI, no side effects — deterministic when given a DeterministicRNG.

var rng: RNG
var num_dice: int
var values: Array[int]       ## current face values (0 = not yet rolled)
var locked: Array[bool]      ## which dice are locked
var rolls_left: int
var max_rolls: int


func _init(p_rng: RNG, p_num_dice: int = 3, p_max_rolls: int = 3) -> void:
	rng = p_rng
	num_dice = p_num_dice
	max_rolls = p_max_rolls
	values = []
	locked = []
	for i in num_dice:
		values.append(0)
		locked.append(false)
	rolls_left = max_rolls


func reset_turn(bonus_rolls: int = 0) -> void:
	for i in num_dice:
		values[i] = 0
		locked[i] = false
	rolls_left = max_rolls + bonus_rolls


func roll() -> bool:
	## Roll all unlocked dice. Returns false if no rolls remain.
	if rolls_left <= 0:
		return false
	var rolled_any := false
	for i in num_dice:
		if not locked[i]:
			values[i] = rng.rand_int(1, 6)
			rolled_any = true
	if rolled_any:
		rolls_left -= 1
	return rolled_any


func lock(index: int) -> void:
	if index >= 0 and index < num_dice and values[index] > 0:
		locked[index] = true


func unlock(index: int) -> void:
	if index >= 0 and index < num_dice:
		locked[index] = false


func toggle_lock(index: int) -> void:
	if index >= 0 and index < num_dice and values[index] > 0:
		locked[index] = not locked[index]


func has_rolled() -> bool:
	for v in values:
		if v > 0:
			return true
	return false


# ------------------------------------------------------------------
# Combo scoring — exact port of Python calculate_damage / _get_damage_preview
# ------------------------------------------------------------------

func calc_combo_bonus() -> int:
	## Return bonus damage from dice combos (pairs, triples, straights, etc.)
	if not has_rolled():
		return 0

	var counts := _count_values()
	var bonus := 0

	# Sets: pair / triple / quad / five-of-a-kind
	for value in counts:
		var count: int = counts[value]
		if count >= 5:
			bonus += value * 20
		elif count == 4:
			bonus += value * 10
		elif count == 3:
			bonus += value * 5
		elif count == 2:
			bonus += value * 2

	# Full House (exactly 1 triple + 1 pair, 2 distinct values)
	if counts.size() == 2:
		var vals := counts.values()
		if (vals[0] == 3 and vals[1] == 2) or (vals[0] == 2 and vals[1] == 3):
			bonus += 50

	# Flush (all same AND at least 5 dice)
	if counts.size() == 1 and num_dice >= 5:
		var value: int = counts.keys()[0]
		bonus += value * 15

	# Straights
	var sorted_unique := _sorted_unique()
	if sorted_unique == [1, 2, 3, 4, 5, 6]:
		bonus += 40
	elif sorted_unique.size() >= 4:
		for i in range(sorted_unique.size() - 3):
			var run := sorted_unique.slice(i, i + 4)
			if _is_consecutive(run):
				bonus += 25
				break

	return bonus


func calc_base_damage() -> int:
	var total := 0
	for v in values:
		total += v
	return total


func calc_total_damage(multiplier: float = 1.0, damage_bonus: int = 0) -> int:
	## Total = int(base * multiplier) + combo_bonus + damage_bonus
	var base := calc_base_damage()
	var combo := calc_combo_bonus()
	return int(float(base) * multiplier) + combo + damage_bonus


# ------------------------------------------------------------------
# Internals
# ------------------------------------------------------------------

func _count_values() -> Dictionary:
	var counts := {}
	for v in values:
		if v <= 0:
			continue
		counts[v] = counts.get(v, 0) + 1
	return counts


func _sorted_unique() -> Array[int]:
	var s: Array[int] = []
	for v in values:
		if v > 0 and v not in s:
			s.append(v)
	s.sort()
	return s


static func _is_consecutive(arr: Array) -> bool:
	for i in range(1, arr.size()):
		if arr[i] != arr[i - 1] + 1:
			return false
	return true
