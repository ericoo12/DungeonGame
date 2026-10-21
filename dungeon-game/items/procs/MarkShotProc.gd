## Pink Eye: chance per shot to mark the enemy. Marked enemies take extra damage and
## pass the mark on to other enemies they touch (PinkEyeStatus).
class_name MarkShotProc
extends ShotProcEffect

@export var duration: float = 5.0
@export var damage_taken_mult: float = 1.25
@export var tint: Color = Color(1.0, 0.55, 0.75)


func decorate_projectile(projectile: Node) -> void:
	if projectile is CanvasItem:
		projectile.modulate = tint


func on_hit(target: Node, _player: Player) -> void:
	if target is EnemyBase:
		PinkEyeStatus.apply(target, duration, damage_taken_mult)


func get_stat_text() -> String:
	return "%d%% chance to infect (+%d%% damage taken, spreads on touch)" % [roundi(get_chance() * 100.0), roundi((damage_taken_mult - 1.0) * 100.0)] + luck_text()
