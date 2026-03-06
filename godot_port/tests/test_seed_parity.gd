extends GutTest
## Tests for seed parsing and run configuration parity (Issue A).

func test_negative_seed_accepted() -> void:
	GameSession.start_new_run({"rng_mode": "deterministic", "seed": -42})
	assert_eq(GameSession.run_seed, -42, "Negative seed stored exactly")
	assert_eq(GameSession.run_rng_mode, "deterministic", "RNG mode is deterministic")


func test_zero_seed_accepted() -> void:
	GameSession.start_new_run({"rng_mode": "deterministic", "seed": 0})
	assert_eq(GameSession.run_seed, 0, "Zero seed stored exactly")
	assert_eq(GameSession.run_rng_mode, "deterministic", "RNG mode is deterministic")


func test_large_positive_seed() -> void:
	var big_seed := 9223372036854775807  # max 64-bit signed
	GameSession.start_new_run({"rng_mode": "deterministic", "seed": big_seed})
	assert_eq(GameSession.run_seed, big_seed, "Large positive seed stored exactly")


func test_large_negative_seed() -> void:
	var neg_seed := -9223372036854775807
	GameSession.start_new_run({"rng_mode": "deterministic", "seed": neg_seed})
	assert_eq(GameSession.run_seed, neg_seed, "Large negative seed stored exactly")


func test_seeded_run_deterministic() -> void:
	GameSession.start_new_run({"rng_mode": "deterministic", "seed": 12345})
	var val1 := GameSession.rng.rand_int(1, 100)
	GameSession.start_new_run({"rng_mode": "deterministic", "seed": 12345})
	var val2 := GameSession.rng.rand_int(1, 100)
	assert_eq(val1, val2, "Same seed produces same first random value")


func test_default_run_stores_seed() -> void:
	GameSession.start_new_run({"rng_mode": "default"})
	assert_eq(GameSession.run_rng_mode, "default")
	assert_ne(GameSession.run_seed, -1, "Default run has a real seed from initial_seed")


func test_trace_seed_matches_run_seed() -> void:
	GameSession.start_new_run({"rng_mode": "deterministic", "seed": 99999})
	assert_eq(GameSession.trace.seed_value, 99999, "Trace seed matches run seed")
	assert_eq(GameSession.run_seed, 99999, "Run seed stored correctly")


func test_deterministic_rng_initial_seed_property() -> void:
	var rng := DeterministicRNG.new(777)
	assert_eq(rng.initial_seed, 777, "DeterministicRNG exposes initial_seed")
