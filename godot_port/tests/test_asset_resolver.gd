extends GutTest
## Tests for AssetResolver — verifies enemy sprite and item icon resolution
## follows the exact same rules as the Python implementation.
## All tests are headless (logic-only, no rendering).


# ==================================================================
# Slugify — Python item_icons.py parity
# ==================================================================

func test_slugify_simple_name() -> void:
	assert_eq(AssetResolver.slugify("Health Potion"), "health_potion")


func test_slugify_greater_name() -> void:
	assert_eq(AssetResolver.slugify("Greater Health Potion"), "greater_health_potion")


func test_slugify_apostrophe() -> void:
	assert_eq(AssetResolver.slugify("Charmer's Amulet"), "charmers_amulet")


func test_slugify_unicode_apostrophe() -> void:
	assert_eq(AssetResolver.slugify("Charmer\u2019s Amulet"), "charmers_amulet")


func test_slugify_strips_edges() -> void:
	assert_eq(AssetResolver.slugify("  Iron Sword  "), "iron_sword")


func test_slugify_special_chars() -> void:
	assert_eq(AssetResolver.slugify("Potion (Greater)"), "potion_greater")


func test_slugify_numbers() -> void:
	assert_eq(AssetResolver.slugify("Phase 2 Shield"), "phase_2_shield")


# ==================================================================
# Folder-to-name — Python load_enemy_sprites parity
# ==================================================================

func test_folder_to_name_simple() -> void:
	assert_eq(AssetResolver.folder_to_enemy_name("acid_hydra"), "Acid Hydra")


func test_folder_to_name_charmers() -> void:
	assert_eq(AssetResolver.folder_to_enemy_name("charmers_serpent"), "Charmer's Serpent")


func test_folder_to_name_of_lowercase() -> void:
	assert_eq(AssetResolver.folder_to_enemy_name("jury_of_crows"), "Jury of Crows")


func test_folder_to_name_single_word() -> void:
	assert_eq(AssetResolver.folder_to_enemy_name("skeleton"), "Skeleton")


func test_folder_to_name_rat_swarm() -> void:
	assert_eq(AssetResolver.folder_to_enemy_name("rat_swarm"), "Rat Swarm")


# ==================================================================
# Name-to-folder (reverse)
# ==================================================================

func test_name_to_folder_simple() -> void:
	assert_eq(AssetResolver.enemy_name_to_folder("Acid Hydra"), "acid_hydra")


func test_name_to_folder_apostrophe() -> void:
	assert_eq(AssetResolver.enemy_name_to_folder("Charmer's Serpent"), "charmers_serpent")


# ==================================================================
# Asset resolution paths
# ==================================================================

func test_resolver_has_assets_dir() -> void:
	var resolver := AssetResolver.new()
	assert_true(resolver.has_assets(), "assets directory should be found")


func test_item_icon_path_for_known_item() -> void:
	var resolver := AssetResolver.new()
	if not resolver.has_assets():
		pending("No assets directory found")
		return
	var path := resolver.get_item_icon_path("Health Potion")
	assert_false(path.is_empty(), "path should not be empty")
	assert_true(path.ends_with(".png"), "path should end with .png")


func test_item_icon_path_fallback_for_unknown() -> void:
	var resolver := AssetResolver.new()
	if not resolver.has_assets():
		pending("No assets directory found")
		return
	var path := resolver.get_item_icon_path("Nonexistent Widget 9999")
	assert_true(path.contains("unknown.png"), "should fall back to unknown.png")


func test_enemy_sprite_path_for_known_enemy() -> void:
	var resolver := AssetResolver.new()
	if not resolver.has_assets():
		pending("No assets directory found")
		return
	var path := resolver.get_enemy_sprite_path("Rat Swarm")
	if path.is_empty():
		pending("rat_swarm sprite not found on disk")
		return
	assert_true(path.ends_with(".png"), "path should end with .png")
	assert_true(path.contains("rat_swarm"), "path should contain folder slug")


func test_enemy_sprite_path_empty_for_missing() -> void:
	var resolver := AssetResolver.new()
	var path := resolver.get_enemy_sprite_path("Nonexistent Monster 9999")
	assert_eq(path, "", "missing enemy should return empty string")


# ==================================================================
# Texture loading
# ==================================================================

func test_item_icon_returns_texture_or_null() -> void:
	var resolver := AssetResolver.new()
	if not resolver.has_assets():
		pending("No assets directory found")
		return
	var tex = resolver.get_item_icon("Health Potion")
	# tex may be null if the specific icon doesn't exist
	# but should not crash
	if tex != null:
		assert_true(tex is ImageTexture, "returned value is ImageTexture")


func test_enemy_sprite_returns_texture_or_null() -> void:
	var resolver := AssetResolver.new()
	if not resolver.has_assets():
		pending("No assets directory found")
		return
	var tex = resolver.get_enemy_sprite("Acid Hydra")
	if tex != null:
		assert_true(tex is ImageTexture, "returned value is ImageTexture")


func test_missing_asset_returns_null() -> void:
	var resolver := AssetResolver.new()
	var tex = resolver.get_enemy_sprite("Utterly Fake Monster That Does Not Exist XYZ")
	assert_null(tex, "missing enemy returns null, not crash")


func test_cache_returns_same_object() -> void:
	var resolver := AssetResolver.new()
	if not resolver.has_assets():
		pending("No assets directory found")
		return
	var tex1 = resolver.get_enemy_sprite("Acid Hydra")
	var tex2 = resolver.get_enemy_sprite("Acid Hydra")
	assert_same(tex1, tex2, "cached result returns identical object")


func test_clear_cache() -> void:
	var resolver := AssetResolver.new()
	resolver.get_enemy_sprite("Acid Hydra")
	resolver.clear_cache()
	assert_true(resolver._enemy_cache.is_empty(), "cache cleared")


# ==================================================================
# GameSession integration
# ==================================================================

func test_game_session_has_assets() -> void:
	assert_not_null(GameSession.assets, "GameSession.assets should exist")
	assert_true(GameSession.assets is AssetResolver, "GameSession.assets is AssetResolver")
