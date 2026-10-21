## U-Bend's shot: flies out, slows to a stop, then flies back to the player.
## Goes through enemies (hits each one once on the way out and once on the way back),
## turns around early when it hits a wall or obstacle, and flies over walls on the way
## back so it can't get stuck. On the way back it flies THROUGH the player and keeps
## going for `overshoot_distance` px before it drops (it isn't caught).
## Range stat = how far it goes out; shot speed = how fast.
class_name BoomerangProjectile
extends Projectile

## Launch speed compared to a normal shot (it decelerates, so it starts faster).
@export var launch_speed_boost: float = 1.8
## Share of `lifetime` spent flying out before turning around.
@export var out_ratio: float = 0.7
## Top speed on the way back, compared to the launch speed.
@export var return_speed_ratio: float = 1.1
@export var spin_speed: float = 14.0
## Safety net: lands after this many seconds no matter what.
@export var max_flight_time: float = 4.0
## How close it has to come to the player before it stops homing and flies straight on.
@export var pass_distance: float = 12.0
## How far it keeps flying past the player before it drops.
@export var overshoot_distance: float = 90.0

var _dir: Vector2 = Vector2.RIGHT
var _speed0: float = 0.0
var _out_time: float = 0.5
var _returning: bool = false
var _return_speed: float = 0.0
var _hit_this_leg: Array[Node] = []
var _passed_player: bool = false
var _overshoot_left: float = 0.0


func launch(aim_dir: Vector2, shooter_velocity: Vector2) -> void:
	super.launch(aim_dir, shooter_velocity)
	velocity *= launch_speed_boost
	_speed0 = velocity.length()
	_dir = velocity.normalized() if _speed0 > 0.0 else aim_dir
	_out_time = maxf(lifetime * out_ratio, 0.15)


func _physics_process(delta: float) -> void:
	if has_landed:
		return
	elapsed += delta
	if not _returning:
		var t := elapsed / _out_time
		velocity = _dir * _speed0 * maxf(1.0 - t, 0.0)
		if t >= 1.0:
			_start_return()
	elif not _passed_player:
		if not is_instance_valid(shooter):
			_land()
			return
		var target: Vector2 = shooter.get_hurtbox_center()
		var to_target := target - global_position
		_return_speed = minf(_return_speed + _speed0 * 3.0 * delta, _speed0 * return_speed_ratio)
		# Reached the player, or already flying away from them: stop homing, fly on straight.
		if to_target.length() <= pass_distance or (velocity != Vector2.ZERO and to_target.dot(velocity) < 0.0):
			_passed_player = true
			_overshoot_left = overshoot_distance
			if velocity == Vector2.ZERO:
				velocity = -_dir * _return_speed
		else:
			velocity = to_target.normalized() * _return_speed
	else:
		_overshoot_left -= velocity.length() * delta
		if _overshoot_left <= 0.0:
			_land()
			return
	global_position += velocity * delta
	sprite_rotator.rotation += spin_speed * delta
	if elapsed >= max_flight_time:
		_land()


func _start_return() -> void:
	if _returning:
		return
	_returning = true
	_hit_this_leg.clear()
	_return_speed = _speed0 * 0.25


func _try_deal_damage(target: Node) -> void:
	if has_landed or target == ignored_target:
		return
	if target is Obstacle or target.is_in_group("walls") or target.is_in_group("projectile_blockers"):
		if not _returning:
			if target.has_method("take_damage"):
				target.take_damage(damage, _dir, knockback_strength)  # breakables still count the hit
			_start_return()
		return  # on the way back it flies over walls and obstacles
	if target.has_method("take_damage"):
		if _hit_this_leg.has(target):
			return
		_hit_this_leg.append(target)
		var hit_dir := velocity.normalized() if velocity != Vector2.ZERO else _dir
		target.take_damage(damage, hit_dir, knockback_strength)
		for proc in procs:
			proc.on_hit(target, shooter)
			proc.on_projectile_hit(self, target)
