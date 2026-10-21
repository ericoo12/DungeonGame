# ChaseMovement.gd — walks straight at the player, always
class_name ChaseMovement
extends MovementBehavior

func get_velocity(enemy: EnemyBase, delta: float) -> Vector2:
	if not enemy.player:
		return Vector2.ZERO
	var dir: Vector2 = (enemy.player.global_position - enemy.global_position).normalized()
	enemy._update_facing_direction(dir)
	return dir * enemy.move_speed
