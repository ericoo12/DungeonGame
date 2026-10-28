# StrafeBurstMovement.gd — Pipe Spider: darts sideways (relative to the player) in short
# bursts, pausing in between. Sometimes the burst angles in towards the player, so it
# slowly closes in while being hard to predict.
class_name StrafeBurstMovement
extends MovementBehavior

@export var burst_speed: float = 140.0
@export var burst_time: float = 0.3
@export var pause_time: Vector2 = Vector2(0.3, 0.7)
## 0 = pure sideways, 1 = straight at the player. Each burst picks a random amount
## between min_approach and max_approach, so it always creeps closer while zig-zagging.
@export var min_approach: float = 0.45
@export var max_approach: float = 0.8

var _timer: float = 0.0
var _bursting: bool = false
var _dir: Vector2 = Vector2.ZERO


func get_velocity(enemy: EnemyBase, delta: float) -> Vector2:
	_timer -= delta
	if _bursting:
		if _timer <= 0.0 or enemy.get_slide_collision_count() > 0:
			_bursting = false
			_timer = randf_range(pause_time.x, pause_time.y)
			return Vector2.ZERO
		return _dir * burst_speed
	if _timer > 0.0 or enemy.player == null:
		return Vector2.ZERO
	var to_player := (enemy.player.global_position - enemy.global_position).normalized()
	var side := to_player.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
	_dir = side.lerp(to_player, randf_range(min_approach, max_approach)).normalized()
	_bursting = true
	_timer = burst_time
	enemy._update_facing_direction(_dir)
	return _dir * burst_speed
