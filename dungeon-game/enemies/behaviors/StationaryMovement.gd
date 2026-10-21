# StationaryMovement.gd — never moves, just tracks facing (turret-style)
class_name StationaryMovement
extends MovementBehavior

func get_velocity(enemy: EnemyBase, delta: float) -> Vector2:
	if enemy.player:
		var dir: Vector2 = (enemy.player.global_position - enemy.global_position).normalized()
		enemy._update_facing_direction(dir)
	return Vector2.ZERO
