class_name GameOverResolver
extends RefCounted
## Determines when the run ends and produces a summary.
## Mirrors Python game_over() / show_victory() logic.

enum EndReason { DEATH, VICTORY }


class RunSummary extends RefCounted:
	var end_reason: EndReason = EndReason.DEATH
	var floor_reached: int = 1
	var rooms_explored: int = 0
	var enemies_defeated: int = 0
	var bosses_defeated: int = 0
	var mini_bosses_defeated: int = 0
	var gold_earned: int = 0
	var items_found: int = 0
	var chests_opened: int = 0
	var run_score: int = 0
	var victory_bonus: int = 0
	var final_score: int = 0


static func is_player_dead(state: GameState) -> bool:
	return state.health <= 0


static func build_summary(state: GameState, floor_st: FloorState,
		reason: EndReason) -> RunSummary:
	var s := RunSummary.new()
	s.end_reason = reason
	s.floor_reached = state.floor
	s.rooms_explored = floor_st.rooms_explored if floor_st != null else 0
	s.enemies_defeated = int(state.stats.get("enemies_defeated", 0))
	s.bosses_defeated = int(state.stats.get("bosses_defeated", 0))
	s.mini_bosses_defeated = floor_st.mini_bosses_defeated if floor_st != null else 0
	s.gold_earned = state.total_gold_earned
	s.items_found = int(state.stats.get("items_found", 0))
	s.chests_opened = int(state.stats.get("chests_opened", 0))
	s.run_score = int(state.stats.get("run_score", 0))

	if reason == EndReason.VICTORY:
		s.victory_bonus = 5000
	s.final_score = s.run_score + s.victory_bonus
	return s
