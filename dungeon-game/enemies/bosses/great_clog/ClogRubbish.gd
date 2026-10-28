## Loose rubbish on the Great Clog's floor (a duck, a bottle cap, a bag...).
## Harmless while it lies still on a dry floor. It hurts the player (half a heart, then
## breaks apart and is gone) when:
##   - the boss PULLS every piece back to its mouth (pull_to) - pieces fly through the
##     room towards the drain, so stand clear of the lines between them and the boss,
##   - it's FLOATING in the phase 2 water (add_external_push): drifting debris you have
##     to dodge, or shoot - a player shot breaks a floating piece,
##   - it's moving fast for any other reason.
## Pieces that reach the mouth are "eaten" (signal), the boss coughs them back out later.
extends Node2D
class_name ClogRubbish

signal eaten

const DUCK_TEX := preload("res://assets/sprites/pickups/ducks/duck_1.png")
## trash_bag.png is the obstacle's 4-frame sheet (16x20 each): only use its first frame.
const BAG_SHEET := preload("res://assets/sprites/objects/trash_bag.png")
const POT_TEX := preload("res://assets/sprites/objects/pot.png")
static var _textures: Array = []


## A random piece of rubbish art (also used for the boss's rubbish rows).
static func random_texture() -> Texture2D:
	if _textures.is_empty():
		var bag := AtlasTexture.new()
		bag.atlas = BAG_SHEET
		bag.region = Rect2(0, 0, 16, 20)
		_textures = [DUCK_TEX, bag, POT_TEX]
	return _textures.pick_random()

@export var size_px: float = 10.0
@export var friction: float = 140.0
## Moving at least this fast (px/s) = hurts on touch.
@export var hurt_speed: float = 70.0
@export var damage: float = 0.5

var velocity: Vector2 = Vector2.ZERO
var floor_rect: Rect2 = Rect2()
var _push: Vector2 = Vector2.ZERO
var _pull_target: Vector2
var _pull_speed: float = 0.0
var _hurt_cooldown: float = 0.0
var _shake: float = 0.0
var _sprite: Sprite2D
var _height: float = 0.0
var _vz: float = 0.0
var _spin: float = 0.0
var _floating: bool = false
var _breaking: bool = false


func _ready() -> void:
	add_to_group("clog_rubbish")
	add_to_group("room_effects")
	_sprite = Sprite2D.new()
	_sprite.texture = random_texture()
	var s := _sprite.texture.get_size()
	_sprite.scale = Vector2.ONE * (size_px / maxf(s.x, s.y))
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.modulate = Color(0.8, 0.75, 0.6)  # grimy
	_sprite.rotation = randf_range(-0.6, 0.6)
	add_child(_sprite)


## Thrown out in an arc to `target` (lands harmlessly).
func toss_to(target: Vector2, time: float = 0.6) -> void:
	velocity = (target - global_position) / time
	_vz = 150.0 * time  # gravity 300: back on the floor after `time` seconds
	_height = 0.1
	_hurt_cooldown = time + 0.2  # harmless while flying out


func warn() -> void:
	_shake = 0.6


func pull_to(target: Vector2, speed: float) -> void:
	_pull_target = target
	_pull_speed = speed


func is_pulled() -> bool:
	return _pull_speed > 0.0


func add_external_push(push: Vector2) -> void:
	_push += push


func _physics_process(delta: float) -> void:
	if _breaking:
		return
	_hurt_cooldown -= delta
	if _height > 0.0:
		_vz -= 300.0 * delta
		_height = maxf(0.0, _height + _vz * delta)
		if _height <= 0.0:
			velocity *= 0.25
	if _pull_speed > 0.0:
		var to := _pull_target - global_position
		if to.length() < 8.0:
			eaten.emit()
			queue_free()
			return
		velocity = to.normalized() * _pull_speed
	elif _height <= 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	_floating = _push.length() > 1.0
	var move := velocity + _push
	_push = Vector2.ZERO
	global_position += move * delta
	_keep_on_floor()
	_spin += move.length() * delta * 0.08
	_sprite.rotation = _spin
	var shake_x := 0.0
	if _shake > 0.0:
		_shake -= delta
		shake_x = sin(_shake * 70.0) * 1.0
	var bob := sin(_spin * 3.0 + float(get_instance_id() % 7)) * 1.0 if _floating else 0.0
	_sprite.position = Vector2(shake_x, -_height - 2.0 + bob)
	if _height < 4.0 and (_floating or _pull_speed > 0.0 or move.length() >= hurt_speed):
		_try_hurt(move)
	if _floating:
		_check_shot()


## Player shots break floating debris (it's in their way anyway).
func _check_shot() -> void:
	for p in get_tree().get_nodes_in_group("projectiles"):
		if p is EnemyProjectile or not (p is Node2D):
			continue
		# Swept check: fast shots move several px per frame.
		var now: Vector2 = (p as Node2D).global_position
		var vel: Vector2 = p.get("velocity") if p.get("velocity") is Vector2 else Vector2.ZERO
		var before := now - vel * get_physics_process_delta_time()
		if Geometry2D.get_closest_point_to_segment(global_position, before, now).distance_to(global_position) < 10.0:
			if p.has_method("_land"):
				p.call("_land")
			_break()
			return


## Bursts apart and disappears.
func _break() -> void:
	if _breaking:
		return
	_breaking = true
	remove_from_group("clog_rubbish")
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "scale", _sprite.scale * 1.6, 0.18)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(queue_free)


func _keep_on_floor() -> void:
	if not floor_rect.has_area() or _pull_speed > 0.0:
		return
	var r := floor_rect.grow(-4.0)
	var p := global_position
	if p.x < r.position.x or p.x > r.end.x:
		velocity.x = -velocity.x * 0.5
	if p.y < r.position.y or p.y > r.end.y:
		velocity.y = -velocity.y * 0.5
	global_position = p.clamp(r.position, r.end)


func _try_hurt(move: Vector2) -> void:
	if _hurt_cooldown > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var p: Vector2 = player.call("get_hurtbox_center") if player.has_method("get_hurtbox_center") else player.global_position
	if p.distance_to(global_position) < 9.0 and player.has_method("take_damage"):
		if "invulnerable" in player and player.invulnerable:
			return  # already flashing: drift on, don't waste the piece
		player.take_damage(damage, move.normalized() if move.length() > 1.0 else (p - global_position).normalized(), 120.0)
		_break()
