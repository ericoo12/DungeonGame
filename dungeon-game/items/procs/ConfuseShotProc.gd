## Chance per shot to confuse the enemy hit (Soap in Your Eyes): it stumbles around in
## random directions and can't attack for `duration` seconds. Bosses are immune.
class_name ConfuseShotProc
extends ShotProcEffect

@export var duration: float = 2.0
@export var tint: Color = Color(1.0, 0.7, 0.95)


func decorate_projectile(projectile: Node) -> void:
	if projectile is CanvasItem:
		projectile.modulate = tint


func on_hit(target: Node, _player: Player) -> void:
	if target.has_method("apply_confuse"):
		target.apply_confuse(duration)


func get_stat_text() -> String:
	return "%d%% chance to confuse for %ss" % [roundi(get_chance() * 100.0), str(duration)] + luck_text()
