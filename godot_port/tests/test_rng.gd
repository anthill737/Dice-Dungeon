extends GutTest
## Tests for the RNG injection system.
## Mirrors Python tests/test_rng_determinism.py.


# ---- Same seed → identical sequences ----

func test_same_seed_rand_int():
	var a := DeterministicRNG.new(12345)
	var b := DeterministicRNG.new(12345)
	var seq_a: Array = []
	var seq_b: Array = []
	for i in 50:
		seq_a.append(a.rand_int(1, 100))
		seq_b.append(b.rand_int(1, 100))
	assert_eq(seq_a, seq_b, "rand_int sequences should match with same seed")


func test_same_seed_randf():
	var a := DeterministicRNG.new(12345)
	var b := DeterministicRNG.new(12345)
	var seq_a: Array = []
	var seq_b: Array = []
	for i in 30:
		seq_a.append(a.randf())
		seq_b.append(b.randf())
	assert_eq(seq_a, seq_b, "randf sequences should match with same seed")


func test_same_seed_choice():
	var a := DeterministicRNG.new(12345)
	var b := DeterministicRNG.new(12345)
	var pool := [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
	var seq_a: Array = []
	var seq_b: Array = []
	for i in 30:
		seq_a.append(a.choice(pool))
		seq_b.append(b.choice(pool))
	assert_eq(seq_a, seq_b, "choice sequences should match with same seed")


func test_same_seed_shuffle():
	var a := DeterministicRNG.new(12345)
	var b := DeterministicRNG.new(12345)
	var arr_a := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var arr_b := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	a.shuffle(arr_a)
	b.shuffle(arr_b)
	assert_eq(arr_a, arr_b, "shuffle should produce same order with same seed")


func test_same_seed_sample():
	var a := DeterministicRNG.new(12345)
	var b := DeterministicRNG.new(12345)
	var pop := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
	var sa := a.sample(pop, 5)
	var sb := b.sample(pop, 5)
	assert_eq(sa, sb, "sample should produce same elements with same seed")


# ---- Different seed → different sequences ----

func test_different_seed_rand_int():
	var a := DeterministicRNG.new(111)
	var b := DeterministicRNG.new(222)
	var seq_a: Array = []
	var seq_b: Array = []
	for i in 20:
		seq_a.append(a.rand_int(1, 1000))
		seq_b.append(b.rand_int(1, 1000))
	assert_ne(seq_a, seq_b, "rand_int sequences should differ with different seeds")


func test_different_seed_randf():
	var a := DeterministicRNG.new(111)
	var b := DeterministicRNG.new(222)
	var seq_a: Array = []
	var seq_b: Array = []
	for i in 20:
		seq_a.append(a.randf())
		seq_b.append(b.randf())
	assert_ne(seq_a, seq_b, "randf sequences should differ with different seeds")


func test_different_seed_shuffle():
	var a := DeterministicRNG.new(111)
	var b := DeterministicRNG.new(222)
	var arr_a := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var arr_b := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	a.shuffle(arr_a)
	b.shuffle(arr_b)
	assert_ne(arr_a, arr_b, "shuffle should differ with different seeds")


# ---- DefaultRNG smoke tests ----

func test_default_rng_rand_int_in_range():
	var rng := DefaultRNG.new()
	for i in 100:
		var v := rng.rand_int(1, 6)
		assert_gte(v, 1, "rand_int >= 1")
		assert_lte(v, 6, "rand_int <= 6")


func test_default_rng_randf_in_range():
	var rng := DefaultRNG.new()
	for i in 100:
		var v := rng.randf()
		assert_gte(v, 0.0, "randf >= 0.0")
		assert_lt(v, 1.0, "randf < 1.0")


func test_default_rng_choice_from_pool():
	var rng := DefaultRNG.new()
	var pool := ["a", "b", "c"]
	for i in 50:
		var v = rng.choice(pool)
		assert_true(pool.has(v), "choice should return element from pool")


func test_default_rng_shuffle_preserves_elements():
	var rng := DefaultRNG.new()
	var arr := [1, 2, 3, 4, 5]
	rng.shuffle(arr)
	var sorted_arr := arr.duplicate()
	sorted_arr.sort()
	assert_eq(sorted_arr, [1, 2, 3, 4, 5], "shuffle should preserve elements")


func test_default_rng_sample_returns_k_unique():
	var rng := DefaultRNG.new()
	var pop := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var s := rng.sample(pop, 5)
	assert_eq(s.size(), 5, "sample should return k elements")
	# Check uniqueness
	var seen := {}
	for v in s:
		assert_false(seen.has(v), "sample elements should be unique")
		seen[v] = true


# ---- Gameplay-style determinism ----

func test_combat_round_determinism():
	var seed_val := 98765
	var results_a := _simulate_combat(DeterministicRNG.new(seed_val))
	var results_b := _simulate_combat(DeterministicRNG.new(seed_val))
	assert_eq(results_a, results_b, "same seed should produce identical combat rounds")

	var results_c := _simulate_combat(DeterministicRNG.new(seed_val + 1))
	assert_ne(results_a, results_c, "different seed should produce different combat rounds")


func _simulate_combat(rng: RNG) -> Array:
	var rounds: Array = []
	for i in 10:
		var dice := [rng.rand_int(1, 6), rng.rand_int(1, 6), rng.rand_int(1, 6)]
		var crit := rng.randf() < 0.15
		var damage: int = 0
		for d in dice:
			damage += d
		if crit:
			damage *= 2
		var gold := rng.rand_int(10, 30)
		rounds.append({"dice": dice, "crit": crit, "damage": damage, "gold": gold})
	return rounds


func test_loot_roll_determinism():
	var seed_val := 54321
	var loot_a := _simulate_loot(DeterministicRNG.new(seed_val))
	var loot_b := _simulate_loot(DeterministicRNG.new(seed_val))
	assert_eq(loot_a, loot_b, "same seed should produce identical loot rolls")


func _simulate_loot(rng: RNG) -> Array:
	var results: Array = []
	var items := ["Health Potion", "Weighted Die", "Lucky Chip", "Honey Jar"]
	for i in 10:
		var roll := rng.randf()
		if roll < 0.15:
			results.append("nothing")
		elif roll < 0.50:
			results.append("gold_%d" % rng.rand_int(5, 15))
		elif roll < 0.80:
			results.append(rng.choice(items))
		else:
			results.append("both_%d_%s" % [rng.rand_int(5, 15), rng.choice(items)])
	return results


# ---- Polymorphism: both types satisfy RNG interface ----

func test_default_rng_is_rng():
	var rng := DefaultRNG.new()
	assert_true(rng is RNG, "DefaultRNG should extend RNG")


func test_deterministic_rng_is_rng():
	var rng := DeterministicRNG.new(42)
	assert_true(rng is RNG, "DeterministicRNG should extend RNG")


func test_injection_pattern():
	# Simulates how a game system would accept an optional RNG
	var result_a := _game_system_with_rng(DeterministicRNG.new(999))
	var result_b := _game_system_with_rng(DeterministicRNG.new(999))
	assert_eq(result_a, result_b, "injected RNG should make system deterministic")


func _game_system_with_rng(rng: RNG = null) -> int:
	if rng == null:
		rng = DefaultRNG.new()
	return rng.rand_int(1, 6) + rng.rand_int(1, 6) + rng.rand_int(1, 6)
