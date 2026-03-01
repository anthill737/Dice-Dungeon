class_name DefaultRNG
extends RNG
## Non-deterministic RNG using Godot's global RandomNumberGenerator.
##
## Mirrors Python's DefaultRNG (wraps module-level random).
## Each instance has its own RandomNumberGenerator that is randomised
## on creation so sequences are unpredictable.

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func rand_int(a: int, b: int) -> int:
	return _rng.randi_range(a, b)


func randf() -> float:
	return _rng.randf()


func choice(arr: Array) -> Variant:
	return arr[_rng.randi_range(0, arr.size() - 1)]


func shuffle(arr: Array) -> void:
	# Fisher-Yates (Knuth) shuffle — in place
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
