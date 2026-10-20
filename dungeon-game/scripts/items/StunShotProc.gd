## Stuns the enemy hit for `duration` seconds (no movement, no attacks). Used by
## Emergency Wrench's projectile (always on there; not an item proc by itself).
class_name StunShotProc
extends ShotProcEffect

@export var duration: float = 2.0


func on_hit(target: Node, _player: Player) -> void:
	if target.has_method("apply_stun"):
		target.apply_stun(duration)


func get_stat_text() -> String:
	return "Stuns for %ss" % str(duration)
