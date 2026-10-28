# ScurryMovement.gd — Sewer Roach: wanders around slowly; when the player comes close
# it panics and scurries straight ahead (its current heading) at high speed for a moment.
class_name ScurryMovement
extends MovementBehavior

@export var wander_speed: float = 22.0
@export var alert_radius: float = 70.0
@export var scurry_speed: float = 170.0
@export var scurry_time: float = 0.55
@export var scurry_cooldown: float = 0.9

var _dir: Vector2 = Vector2.ZERO
var _turn_timer: float = 0.0
var _scurry_timer: float = 0.0
var _cooldown: float = 0.0


func get_velocity(enemy: EnemyBase, delta: float) -> Vector2:
	_cooldown -= delta
	if _scurry_timer > 0.0:
		_scurry_timer -= delta
		if enemy.get_slide_collision_count() > 0:  # ran into something: turn off it
			_dir = _dir.bounce(enemy.get_slide_collision(0).get_normal()).normalized()
			enemy._update_facing_direction(_dir)
		return _dir * scurry_speed
	if _dir == Vector2.ZERO:
		_dir = Vector2.RIGHT.rotated(randf() * TAU)
	if enemy.player and _cooldown <= 0.0 \
			and enemy.global_position.distance_to(enemy.player.global_position) < alert_radius:
		# Straight ahead - unless "ahead" is right at the player, then veer off to a side.
		var to_player := (enemy.player.global_position - enemy.global_position).normalized()
		if _dir.dot(to_player) > 0.6:
			_dir = to_player.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
		_scurry_timer = scurry_time
		_cooldown = scurry_time + scurry_cooldown
		enemy._update_facing_direction(_dir)
		return _dir * scurry_speed
	_turn_timer -= delta
	if _turn_timer <= 0.0 or enemy.get_slide_collision_count() > 0:
		_turn_timer = randf_range(0.8, 2.0)
		_dir = Vector2.RIGHT.rotated(randf() * TAU)
		enemy._update_facing_direction(_dir)
	return _dir * wander_speed
