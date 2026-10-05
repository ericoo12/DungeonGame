## Chance per shot to fire a slowing shot. Chance scales with luck via ShotProcEffect
## (base_chance at 0 luck -> 100% at luck_for_max).
class_name SlowShotProc
extends ShotProcEffect

@export var slow_factor: float = 0.5        # enemy moves at 50% speed
@export var duration: float = 2.0           # seconds
@export var tint: Color = Color(0.55, 0.75, 1.0)


func decorate_projectile(projectile: Node) -> void:
	if projectile is CanvasItem:
		projectile.modulate = tint


func on_hit(target: Node, _player: Player) -> void:
	if target.has_method("apply_slow"):
		target.apply_slow(slow_factor, duration)


func get_stat_text() -> String:
	return "%d%% chance to slow enemies (100%% at %d luck)" % [roundi(get_chance() * 100.0), roundi(luck_for_max)]
