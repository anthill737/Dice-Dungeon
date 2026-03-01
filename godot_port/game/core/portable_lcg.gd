class_name PortableLCG
extends RNG
## Portable Linear Congruential Generator for cross-language parity tests.
##
## Produces identical sequences in both Python and Godot given the same seed.
## Uses Lehmer/Park-Miller parameters: multiplier=48271, modulus=2^31-1.

const MODULUS: int = 2147483647      ## 2^31 - 1
const MULTIPLIER: int = 48271

var _state: int


func _init(seed_value: int = 42) -> void:
	_state = seed_value % MODULUS
	if _state == 0:
		_state = 1


func _next() -> int:
	_state = (_state * MULTIPLIER) % MODULUS
	return _state


func randf() -> float:
	return float(_next()) / float(MODULUS)


func rand_int(a: int, b: int) -> int:
	return a + (_next() % (b - a + 1))


func choice(arr: Array) -> Variant:
	var idx := _next() % arr.size()
	return arr[idx]


func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _next() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func sample(population: Array, k: int) -> Array:
	var pool := population.duplicate()
	var result: Array = []
	for i in range(mini(k, pool.size())):
		var idx := _next() % pool.size()
		result.append(pool[idx])
		pool.remove_at(idx)
	return result
