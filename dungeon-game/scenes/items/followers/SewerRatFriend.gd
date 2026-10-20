## Sewer Rat Friend: follows the player; when an enemy comes within `notice_range` it
## runs over (ignoring walls), bites it once, runs back, and rests for `cooldown`.
## States: FOLLOW -> CHASE -> (bite) -> RETURN -> FOLLOW.
class_name SewerRatFriend
extends TrailFollower

enum State { FOLLOW, CHASE, RETURN }

@export var notice_range: float = 110.0
@export var run_speed: float = 150.0
@export var bite_range: float = 10.0
@export var damage_ratio: float = 1.0
@export var bite_knockback: float = 80.0
@export var cooldown: float = 1.4
## Gives up a chase after this long (target running away / behind something).
@export var max_chase_time: float = 2.0
@export var anim_fps: float = 12.0

var state: State = State.FOLLOW
var _target: EnemyBase = null
var _cooldown_left: float = 0.5
var _chase_time: float = 0.0
var _anim_time: float = 0.0


func _spawn_puddle() -> void:
	pass


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player_ref):
		queue_free()
		return
	_cooldown_left -= delta
	match state:
		State.FOLLOW:
			super._physics_process(delta)
			if _cooldown_left <= 0.0:
				_target = _find_target()
				if _target:
					state = State.CHASE
					_chase_time = 0.0
		State.CHASE:
			_chase_time += delta
			if not is_instance_valid(_target) or _target.is_dying or _chase_time > max_chase_time:
				state = State.RETURN
			else:
				_run_to(_target.global_position, delta)
				if global_position.distance_to(_target.global_position) <= bite_range:
					_bite(_target)
					state = State.RETURN
		State.RETURN:
			_run_to(player_ref.global_position, delta)
			if global_position.distance_to(player_ref.global_position) <= 24.0:
				state = State.FOLLOW
				_cooldown_left = cooldown


func _process(delta: float) -> void:
	var s := sprite as Sprite2D
	if s and s.hframes > 1:
		_anim_time += delta * anim_fps * (2.0 if state != State.FOLLOW else 1.0)
		s.frame = int(_anim_time) % s.hframes


func _run_to(target: Vector2, delta: float) -> void:
	var before := global_position
	global_position = global_position.move_toward(target, run_speed * delta)
	var dx := global_position.x - before.x
	if absf(dx) > 0.01:
		(sprite as Sprite2D).flip_h = dx > 0.0  # the rat art faces left


func _find_target() -> EnemyBase:
	var best: EnemyBase = null
	var best_d := notice_range
	for node in get_parent().get_children():
		var e := node as EnemyBase
		if e == null or e.is_dying or e.spawn_timer > 0.0:
			continue
		var d := player_ref.global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _bite(enemy: EnemyBase) -> void:
	var dir := (enemy.global_position - global_position).normalized()
	enemy.take_damage(maxf(player_ref.get_effective_damage() * damage_ratio, 0.5), dir, bite_knockback)
