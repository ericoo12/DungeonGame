# WanderMovement.gd — ignores the player entirely until within alert_radius
class_name WanderMovement
extends MovementBehavior

@export var alert_radius: float = 150.0
@export var wander_speed: float = 20.0

var wander_dir: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0

func get_velocity(enemy: EnemyBase, delta: float) -> Vector2:
	if enemy.player:
		var dist: float = enemy.global_position.distance_to(enemy.player.global_position)
		if dist <= alert_radius:
			var dir: Vector2 = (enemy.player.global_position - enemy.global_position).normalized()
			enemy._update_facing_direction(dir)
			return dir * enemy.move_speed

	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.0, 2.5)
		wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		enemy._update_facing_direction(wander_dir)
	return wander_dir * wander_speed
