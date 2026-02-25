class_name RNG
extends RefCounted
## Abstract RNG interface for Dice Dungeon.
##
## Mirrors the Python rng.py API so both ports share identical semantics.
## All game subsystems accept an RNG instance for dependency injection;
## pass null / omit to get DefaultRNG behaviour.
##
## Methods
## -------
## rand_int(a, b) -> int      Inclusive on both ends: a <= N <= b
## randf()        -> float     [0.0, 1.0)
## choice(arr)    -> Variant   Random element from a non-empty Array
## shuffle(arr)   -> void      In-place Fisher-Yates shuffle
## sample(arr, k) -> Array     k unique elements (order may differ)


## Return random int N such that a <= N <= b (inclusive).
func rand_int(_a: int, _b: int) -> int:
	push_error("RNG.rand_int() is abstract — override in subclass")
	return _a


## Return a random float in [0.0, 1.0).
func randf() -> float:
	push_error("RNG.randf() is abstract — override in subclass")
	return 0.0


## Return a random element from non-empty array.
func choice(_arr: Array) -> Variant:
	push_error("RNG.choice() is abstract — override in subclass")
	return null


## Shuffle array in place.
func shuffle(_arr: Array) -> void:
	push_error("RNG.shuffle() is abstract — override in subclass")


## Return k unique elements chosen from population.
func sample(_population: Array, _k: int) -> Array:
	push_error("RNG.sample() is abstract — override in subclass")
	return []
