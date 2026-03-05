class_name CombatLogFormatter
extends RefCounted
## Produces exact Python-parity combat log strings.
##
## All text generation lives here so UI, trace, and AdventureLog
## emit identical wording.  The class is pure-static; no state.

# ------------------------------------------------------------------
# Combat encounter
# ------------------------------------------------------------------

static func encounter_boss(enemy_name: String) -> Array:
	return [
		"=" .repeat(60),
		"☠ FLOOR BOSS ☠",
		"⚔️  %s  ⚔️" % enemy_name.to_upper(),
		"=" .repeat(60),
	]

static func encounter_mini_boss(enemy_name: String) -> Array:
	return [
		"⚡ %s ⚡ (MINI-BOSS)" % enemy_name.to_upper(),
		"A powerful guardian blocks your path!",
	]

static func encounter_normal(enemy_name: String) -> String:
	return "%s blocks your path!" % enemy_name

static func enemy_stats(hp: int, dice: int) -> String:
	return "Enemy HP: %d | Dice: %d" % [hp, dice]

# ------------------------------------------------------------------
# Player roll
# ------------------------------------------------------------------

static func no_rolls_left() -> String:
	return "No rolls left! You must ATTACK now!"

static func all_dice_locked() -> String:
	return "All dice are locked! Unlock some dice or ATTACK!"

static func no_dice_rolled() -> String:
	return "Roll the dice first!"

static func player_roll(dice_str: String, restriction_note: String, potential_info: String) -> String:
	return "⚄ You rolled: [%s]%s - %s" % [dice_str, restriction_note, potential_info]

# ------------------------------------------------------------------
# Player attack
# ------------------------------------------------------------------

static func fumble(lost_value: int) -> String:
	return "⚠️ You fumble! Lost a %d from your attack." % lost_value

static func player_attack(damage: int) -> String:
	return "⚔️ You attack and deal %d damage!" % damage

static func player_hit(target_name: String, damage: int, is_crit: bool) -> String:
	if is_crit:
		return "Hit %s for %d damage (CRIT!)" % [target_name, damage]
	return "Hit %s for %d damage" % [target_name, damage]

static func damage_reduction_applied(reduction: int, original: int, final_dmg: int) -> String:
	return "🛡️ Enemy's defenses reduce %d damage! (%d → %d)" % [reduction, original, final_dmg]

static func target_locked(name: String, hp: int, max_hp: int) -> String:
	return "● Target locked: %s (%d/%d HP)" % [name, hp, max_hp]

# ------------------------------------------------------------------
# Enemy attack
# ------------------------------------------------------------------

static func enemy_roll(enemy_name: String, dice_str: String) -> String:
	return "%s rolls: [%s]" % [enemy_name, dice_str]

static func enemy_attack(enemy_name: String, damage: int) -> String:
	return "⚔️ %s attacks for %d damage!" % [enemy_name, damage]

static func enemy_just_spawned(enemy_name: String) -> String:
	return "%s is too dazed to attack (just spawned)!" % enemy_name

# ------------------------------------------------------------------
# Damage to player
# ------------------------------------------------------------------

static func shield_absorb(absorbed: int, remaining: int) -> String:
	return "Your shield absorbs %d damage! (Shield: %d remaining)" % [absorbed, remaining]

static func armor_block(blocked: int) -> String:
	return "Your armor blocks %d damage!" % blocked

static func player_takes_damage(amount: int) -> String:
	return "You take %d damage!" % amount

static func all_damage_blocked() -> String:
	return "All damage blocked!"

# ------------------------------------------------------------------
# Enemy defeat
# ------------------------------------------------------------------

static func enemy_defeated(enemy_name: String) -> String:
	return "%s has been defeated!" % enemy_name

# ------------------------------------------------------------------
# Spawn / split / transform
# ------------------------------------------------------------------

static func enemy_spawned(spawner_name: String, spawn_type: String) -> String:
	return "⚠️ %s summons a %s! ⚠️" % [spawner_name, spawn_type]

static func spawned_stats(spawn_type: String, hp: int, dice: int) -> String:
	return "[SPAWNED] %s - HP: %d | Dice: %d" % [spawn_type, hp, dice]

static func enemy_split(original_name: String, count: int, split_type: String) -> String:
	return "✸ %s splits into %d %ss! ✸" % [original_name, count, split_type]

static func split_stats(split_name: String, hp: int, dice: int) -> String:
	return "[SPLIT] %s - HP: %d | Dice: %d" % [split_name, hp, dice]

static func transformed_stats(name: String, hp: int, dice: int) -> String:
	return "[TRANSFORMED] %s - HP: %d | Dice: %d" % [name, hp, dice]

# ------------------------------------------------------------------
# Abilities / curses
# ------------------------------------------------------------------

static func ability_triggered(message: String) -> String:
	return "⚠️ %s" % message

static func curse_damage(amount: int, message: String) -> String:
	return "☠ Curse damage! You lose %d HP. (%s)" % [amount, message]

static func enemy_regen(enemy_name: String, amount: int) -> String:
	return "💚 %s regenerates %d HP!" % [enemy_name, amount]

# ------------------------------------------------------------------
# Curse expiry
# ------------------------------------------------------------------

static func curse_expired_dice_obscure() -> String:
	return "Your vision clears! Dice values are visible again."

static func curse_expired_dice_restrict() -> String:
	return "The curse fades! Your dice roll normally again."

static func curse_expired_dice_lock() -> String:
	return "The binding breaks! Your dice are unlocked."

static func curse_expired_reroll() -> String:
	return "The curse fades! You can reroll normally again."

static func curse_expired_regen() -> String:
	return "The enemy's regeneration ends."

static func curse_expired_damage_reduction() -> String:
	return "The enemy's defenses fade!"

# ------------------------------------------------------------------
# Status effects
# ------------------------------------------------------------------

static func status_poison(status_name: String, damage: int) -> String:
	return "☠ [%s] You take %d damage!" % [status_name, damage]

static func status_bleed(status_name: String, damage: int) -> String:
	return "▪ [%s] You take %d bleed damage!" % [status_name, damage]

static func status_burn(status_name: String, damage: int) -> String:
	return "✹ [%s] You take %d fire damage!" % [status_name, damage]

static func status_choke(status_name: String) -> String:
	return "≋ [%s] Your attacks are weakened!" % status_name

static func status_hunger(status_name: String) -> String:
	return "◆ [%s] You feel weakened from hunger..." % status_name

static func status_tick_total(damage: int) -> String:
	return "Status effects deal %d damage" % damage

# ------------------------------------------------------------------
# Enemy burn
# ------------------------------------------------------------------

static func enemy_burn_tick(enemy_name: String, damage: int, turns: int) -> String:
	return "🔥 %s takes %d burn damage! (%d turns remaining)" % [enemy_name, damage, turns]

static func enemy_burn_expired(enemy_name: String) -> String:
	return "🔥 %s's burn fades away." % enemy_name

static func enemy_burned_to_death(enemy_name: String) -> String:
	return "💀 %s burned to death!" % enemy_name

# ------------------------------------------------------------------
# Rewards
# ------------------------------------------------------------------

static func gold_reward(amount: int) -> String:
	return "+%d gold!" % amount

static func boss_defeated_banner() -> Array:
	return [
		"=" .repeat(60),
		"☠ FLOOR BOSS DEFEATED! ☠",
	]

static func mini_boss_defeated() -> String:
	return "Mini-boss defeated!"

static func key_fragment(total: int) -> String:
	return "Obtained Boss Key Fragment! (%d/3)" % total

static func boss_clear() -> Array:
	return [
		"[BOSS DEFEATED] The path forward is clear!",
		"[STAIRS] Continue exploring to find the stairs to the next floor.",
		"=" .repeat(60),
	]
