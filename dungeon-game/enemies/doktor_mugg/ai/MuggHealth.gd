extends RefCounted
class_name MuggHealth

## MODIFY: derive tactical multipliers from health. Never mutate baseline settings.
var actor: Node

func _init(boss: Node) -> void:
	actor = boss

func health_defense() -> float:
	if not actor.health_tactics_enabled or actor.is_dying:
		return 0.0
	var ratio = clampf(actor.health / maxf(actor.max_health, 1.0), 0, 1)
	return clampf(1.0 - ratio / maxf(actor.boss_low_health_threshold, 0.01), 0, 1)

func health_aggression() -> float:
	if not actor.health_tactics_enabled or actor.is_dying:
		return 0.0
	var urgency = clampf(1.0 - actor._observed_player_health_ratio / maxf(actor.player_low_health_threshold, 0.01), 0, 1)
	# When both are wounded, self-preservation takes priority progressively.
	return urgency * (1.0 - actor.health_defense())

func effective_preferred_distance() -> float:
	return clampf(actor.preferred_distance + actor.low_boss_extra_distance * actor.health_defense() - actor.low_player_close_in_distance * actor.health_aggression(), actor.close_distance + 10.0, maxf(actor.close_distance + 10.0, actor.attack_range - 25.0))

func effective_attack_cooldown_scale() -> float:
	return lerpf(1.0, actor.low_player_cooldown_scale, actor.health_aggression())

func effective_defense_cooldown_scale() -> float:
	return lerpf(1.0, actor.low_boss_defense_cooldown_scale, actor.health_defense())

func effective_dodge_chance() -> float:
	return clampf(actor.dodge_chance + actor.low_boss_dodge_bonus * actor.health_defense(), 0, 1)

