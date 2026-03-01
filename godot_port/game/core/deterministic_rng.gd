class_name DeterministicRNG
extends RNG
## Seeded RNG that produces repeatable sequences.
##
## Mirrors Python's DeterministicRNG (wraps random.Random(seed)).
## Uses Godot's RandomNumberGenerator with a fixed seed so the same
## seed always yields the same sequence of values.

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 42) -> void:
	_rng.seed = seed_value


func rand_int(a: int, b: int) -> int:
	return _rng.randi_range(a, b)


func randf() -> float:
	return _rng.randf()


func choice(arr: Array) -> Variant:
	return arr[_rng.randi_range(0, arr.size() - 1)]


func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func sample(population: Array, k: int) -> Array:
	var pool := population.duplicate()
	var result: Array = []
	for i in range(mini(k, pool.size())):
		var idx := _rng.randi_range(0, pool.size() - 1)
		result.append(pool[idx])
		pool.remove_at(idx)
	return result
