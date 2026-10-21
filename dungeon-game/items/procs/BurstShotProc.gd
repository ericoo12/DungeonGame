## Bleach Briefs: chance per shot to deal an extra burst of damage on hit
## (`burst_ratio` x the player's shot damage), with a white flash and no extra knockback.
class_name BurstShotProc
extends ShotProcEffect

@export var burst_ratio: float = 1.0
@export var tint: Color = Color(0.92, 0.97, 1.0)


func decorate_projectile(projectile: Node) -> void:
	if projectile is CanvasItem:
		projectile.modulate = tint


func on_hit(target: Node, player: Player) -> void:
	if not is_instance_valid(target) or not is_instance_valid(player):
		return
	var amount := player.get_effective_damage() * burst_ratio
	if target.has_method("take_dot_damage"):
		target.take_dot_damage(amount, Color(2, 2, 2))
	elif target.has_method("take_damage"):
		target.take_damage(amount)


func get_stat_text() -> String:
	return "%d%% chance for a bonus burst of damage" % roundi(get_chance() * 100.0) + luck_text()
