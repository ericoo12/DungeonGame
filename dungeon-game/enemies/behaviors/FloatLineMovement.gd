# FloatLineMovement.gd — Soap Bubble: floats slowly in a straight line (aimed at the
# player when it appears, a little off), bouncing off walls and obstacles. Pair with
# EnemyBase.dies_on_contact so it pops when it touches you.
class_name FloatLineMovement
extends MovementBehavior

@export var aim_spread_degrees: float = 15.0
@export var bob_height: float = 2.0
@export var bob_speed: float = 3.0

var _dir: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _base_y: float = 0.0


func get_velocity(enemy: EnemyBase, delta: float) -> Vector2:
	if _dir == Vector2.ZERO:
		_base_y = enemy.sprite.position.y
		_t = randf() * TAU
		var to_player := Vector2.RIGHT.rotated(randf() * TAU)
		if enemy.player:
			to_player = (enemy.get_player_aim_point() - enemy.global_position).normalized()  # body, not feet
		_dir = to_player.rotated(deg_to_rad(randf_range(-aim_spread_degrees, aim_spread_degrees)))
		enemy._update_facing_direction(_dir)
	for i in enemy.get_slide_collision_count():
		var hit := enemy.get_slide_collision(i)
		if hit.get_collider() is Player:
			continue  # keep pushing into the player: the hitbox touches and it pops
		var n := hit.get_normal()
		if _dir.dot(n) < 0.0:
			_dir = _dir.bounce(n).normalized()
	_t += delta * bob_speed
	enemy.sprite.position.y = _base_y + sin(_t) * bob_height
	return _dir * enemy.move_speed
