## Drain Fly: buzzes around you; every `cooldown` seconds it flies over to the nearest
## (non-boss) enemy and pesters it - circling its head - which CONFUSES it (it stumbles
## around and can't attack) for `confuse_time`. Then it flies back.
## States: FOLLOW -> FLY -> PESTER -> RETURN -> FOLLOW. Flies over walls.
class_name DrainFlyPest
extends TrailFollower

enum State { FOLLOW, FLY, PESTER, RETURN }

@export var notice_range: float = 140.0
@export var fly_speed: float = 170.0
@export var confuse_time: float = 2.0
@export var cooldown: float = 6.0
@export var anim_fps: float = 14.0

var state: State = State.FOLLOW
var _target: EnemyBase = null
var _cooldown_left: float = 1.5
var _timer: float = 0.0
var _anim_time: float = 0.0
var _circle: float = 0.0


func _spawn_puddle() -> void:
	pass


func _process(delta: float) -> void:
	var s := sprite as Sprite2D
	if s and s.hframes > 1:
		_anim_time += delta * anim_fps
		s.frame = int(_anim_time) % s.hframes


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
					state = State.FLY
					_timer = 0.0
		State.FLY:
			_timer += delta
			if not _valid_target() or _timer > 2.5:
				state = State.RETURN
			else:
				var head := _target.global_position + Vector2(0, -10)
				global_position = global_position.move_toward(head, fly_speed * delta)
				if global_position.distance_to(head) < 6.0:
					state = State.PESTER
					_timer = 0.0
					_target.apply_confuse(confuse_time)
		State.PESTER:
			_timer += delta
			if not _valid_target() or _timer >= confuse_time:
				state = State.RETURN
			else:
				_circle += delta * 9.0
				global_position = _target.global_position + Vector2(cos(_circle) * 8.0, -10.0 + sin(_circle) * 4.0)
		State.RETURN:
			global_position = global_position.move_toward(player_ref.global_position, fly_speed * delta)
			if global_position.distance_to(player_ref.global_position) <= 24.0:
				state = State.FOLLOW
				_cooldown_left = cooldown
	sprite.flip_h = (_target.global_position.x < global_position.x) if state == State.FLY and _valid_target() else sprite.flip_h


func _valid_target() -> bool:
	return is_instance_valid(_target) and not _target.is_dying


func _find_target() -> EnemyBase:
	var best: EnemyBase = null
	var best_d := notice_range
	for node in get_parent().get_children():
		var e := node as EnemyBase
		if e == null or e.is_dying or e.is_boss or e.spawn_timer > 0.0 or e._confuse_timer > 0.0:
			continue
		var d := player_ref.global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best
