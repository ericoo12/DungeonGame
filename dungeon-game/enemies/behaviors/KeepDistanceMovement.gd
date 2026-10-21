# KeepDistanceMovement.gd — closes in if too far, backs off if too close
# (the exact "ignores player until in range, then repositions" feel)
class_name KeepDistanceMovement
extends MovementBehavior

@export var preferred_distance: float = 180.0
@export var distance_tolerance: float = 30.0

func get_velocity(enemy: EnemyBase, delta: float) -> Vector2:
	if not enemy.player:
		return Vector2.ZERO
	var to_player: Vector2 = enemy.player.global_position - enemy.global_position
	var dist: float = to_player.length()
	var dir: Vector2 = to_player.normalized()
	enemy._update_facing_direction(dir)

	if dist > preferred_distance + distance_tolerance:
		return dir * enemy.move_speed
	elif dist < preferred_distance - distance_tolerance:
		return -dir * enemy.move_speed
	return Vector2.ZERO
