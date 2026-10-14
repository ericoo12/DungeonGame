extends RefCounted
class_name MuggTactics

## CHOOSE: build the valid responses for ONE situation, then roll their weights.
## This script never moves the body, creates projectiles or advances action time.
enum Situation { DANGER, BLOCKED, TOO_CLOSE, COMBAT, SEARCH }
var actor: Node

func _init(boss: Node) -> void:
	actor = boss

func immediate_danger() -> bool:
	return actor._incoming_threat(true) != null

func player_blocked() -> bool:
	return actor.blackboard.has_last_seen and (not actor.blackboard.player_visible or not actor.blackboard.shot_clear)

func player_too_close() -> bool:
	return actor.blackboard.player_visible and actor.blackboard.distance < actor.close_distance

func player_in_range() -> bool:
	return actor.blackboard.player_visible and actor.blackboard.distance <= actor.attack_range

func choose(situation: Situation) -> DecisionNode.Status:
	actor.blackboard.situation = Situation.keys()[situation]
	var choices = _choices_for(situation)
	actor.blackboard.choice_weights.clear()
	for choice in choices:
		actor.blackboard.choice_weights[choice.name] = choice.weight
	# Remove a failed choice before trying another: never retry the same chance
	# roll in this decision, and never get stuck on an unavailable tactic.
	while not choices.is_empty():
		var index = _weighted_index(choices)
		var choice = choices[index]
		choices.remove_at(index)
		var result = choice.action.call()
		if result != DecisionNode.Status.FAILURE:
			actor.blackboard.chosen_response = choice.name
			if situation in [Situation.COMBAT, Situation.TOO_CLOSE] and actor._offense_timer <= 0:
				actor._offense_timer = actor.tactic_choice_interval
			return result
	actor.blackboard.chosen_response = "No eligible response succeeded"
	return DecisionNode.Status.FAILURE

func _choices_for(situation: Situation) -> Array:
	var choices: Array = []
	match situation:
		Situation.DANGER:
			_offer(choices, "Dodge", actor.danger_dodge_weight * _defense_weight(), _can_dodge(), func(): return actor.ai_dodge())
			_offer(choices, "Take cover", actor.danger_cover_weight * _defense_weight(), _can_cover(), func(): return actor.ai_take_cover())
			_offer(choices, "Running shot", actor.danger_running_shot_weight * _attack_weight(true), _can_running_shot(), func(): return actor.ai_basic_shot("running_shot"))
			_offer(choices, "Retreat", actor.danger_retreat_weight * _defense_weight(), actor.blackboard.has_last_seen, func(): return actor.ai_reposition("Create distance"))
		Situation.BLOCKED:
			_offer(choices, "Flush cover", actor.blocked_area_weight * _attack_weight(false), _can_area(), func(): return actor.ai_area_attack())
			_offer(choices, "Find firing angle", actor.blocked_flank_weight, _can_reposition(), func(): return actor.ai_reposition("Find firing angle"))
			_offer(choices, "Investigate", actor.blocked_investigate_weight, actor.blackboard.has_last_seen, func(): return actor.ai_pressure())
		Situation.TOO_CLOSE:
			_offer(choices, "Running shot", actor.close_running_shot_weight * _attack_weight(true), _can_running_shot(), func(): return actor.ai_basic_shot("running_shot"))
			_offer(choices, "Dash away", actor.close_dodge_weight * _defense_weight(), _can_dodge(true), func(): return actor.ai_dodge(true))
			_offer(choices, "Defensive area", actor.close_area_weight * _defense_weight(), _can_area(), func(): return actor.ai_area_attack())
			_offer(choices, "Retreat", actor.close_retreat_weight * _defense_weight(), true, func(): return actor.ai_reposition("Create distance"))
			_offer(choices, "Take cover", actor.close_cover_weight * _defense_weight(), _can_cover(), func(): return actor.ai_take_cover())
		Situation.COMBAT:
			_offer(choices, "Basic shot", actor.basic_shot_weight * _attack_weight(false), _can_shoot(), func(): return actor.ai_basic_shot())
			_offer(choices, "Cluster shot", actor.cluster_weight * _attack_weight(false), _can_shoot(), func(): return actor.ai_basic_shot("cluster_shot"))
			_offer(choices, "Homing shot", homing_selection_weight() * _attack_weight(false), _can_shoot(), func(): return actor.ai_basic_shot("homing_shot"))
			_offer(choices, "Running shot", actor.running_shot_weight * _attack_weight(true), _can_running_shot(), func(): return actor.ai_basic_shot("running_shot"))
			_offer(choices, "Tactical move", actor.tactical_move_weight * _movement_weight(), _can_reposition(), func(): return actor.ai_reposition("Tactical feint"))
			_offer(choices, "Take cover", actor.combat_cover_weight * actor.health_defense(), _can_cover(), func(): return actor.ai_take_cover())
		Situation.SEARCH:
			_offer(choices, "Approach last sighting", actor.search_approach_weight, actor.blackboard.has_last_seen, func(): return actor.ai_pressure())
			_offer(choices, "Search firing angle", actor.search_reposition_weight, _can_reposition(), func(): return actor.ai_reposition("Reposition"))
	return choices

func _offer(choices: Array, name: String, weight: float, available: bool, action: Callable) -> void:
	if available and weight > 0:
		choices.append({"name": name, "weight": weight, "action": action})

func _weighted_index(choices: Array) -> int:
	var total: float = 0.0
	for choice in choices:
		total += choice.weight
	var roll: float = actor._rng.randf() * total
	for i in choices.size():
		roll -= choices[i].weight
		if roll < 0:
			return i
	return choices.size() - 1

# Eligibility checks never roll dice or change timers.
func _can_shoot() -> bool:
	return actor._offense_timer <= 0 and actor.can_basic_shot()

func _can_running_shot() -> bool:
	return actor.kiting_enabled and _can_shoot()

func _can_reposition() -> bool:
	return actor.blackboard.has_last_seen and actor._reposition_timer <= 0 and actor._movement_retry <= 0

func _can_dodge(allow_retreat: bool = false) -> bool:
	if not actor.dodge_enabled or actor._dodge_timer > 0:
		return false
	return actor._incoming_threat() != null or (allow_retreat and actor.blackboard.player_visible)

func _can_cover() -> bool:
	if not actor.cover_enabled or actor._cover_timer > 0 or not actor.blackboard.has_last_seen:
		return false
	return actor.health_defense() >= actor.proactive_cover_defense_threshold or actor._recent_damage > 0 or immediate_danger()

func _can_area() -> bool:
	if not actor.area_enabled or actor._area_timer > 0 or actor._area_choice_timer > 0:
		return false
	if not actor.blackboard.has_last_seen or actor.blackboard.distance > actor.area_range:
		return false
	return actor._blocked_duration >= actor.area_cover_delay or (actor.blackboard.player_visible and actor.blackboard.distance < actor.area_defensive_distance)

# The same health rules modify choices in every situation.
func _attack_weight(moving_shot: bool) -> float:
	var aggression: float = actor.health_aggression()
	var defense: float = actor.health_defense()
	var defensive_scale: float = actor.wounded_running_attack_scale if moving_shot else actor.wounded_stationary_attack_scale
	return lerpf(1.0, actor.low_player_attack_weight_boost, aggression) * lerpf(1.0, defensive_scale, defense)

func _defense_weight() -> float:
	return lerpf(1.0, actor.low_boss_movement_weight_boost, actor.health_defense())

func _movement_weight() -> float:
	return _defense_weight() * lerpf(1.0, actor.aggressive_movement_scale, actor.health_aggression())

func homing_selection_weight() -> float:
	if actor._homing_timer > 0:
		return 0.0
	var factor: float = clampf((actor.blackboard.distance - actor.homing_near_distance) / maxf(1.0, actor.homing_far_distance - actor.homing_near_distance), 0, 1)
	return maxf(0, lerpf(actor.homing_near_weight, actor.homing_far_weight, factor))
