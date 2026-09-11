extends CharacterBody2D
class_name Player

@export var move_speed: float = 100.0
@export var fire_rate: float = 0.55  # seconds between shots while holding a direction
@export var max_hearts: int = 3
@export var knockback_recovery_speed: float = 800.0
@export var knockback_immune: bool = false
@export var base_damage: float = 3.5
var damage_ups: int = 0
var items: Array[Item] = []

var knockback_velocity: Vector2 = Vector2.ZERO
var current_hearts: int
var invulnerable: bool = false
const INVULN_DURATION := 1.0
var is_dying: bool = false

enum Facing { DOWN, UP, SIDE }

var facing: Facing = Facing.DOWN
var facing_flip: bool = false  # true = facing left
@export var reversed_facing: bool = true  # permanent design choice: character faces/shoots opposite its movement direction
var shoot_timer: float = 0.0
var shoot_cooldown: float = 0.0

const PIERCE_DURATION := 0.2
const PROJECTILE_SCENE := preload("res://scenes/player/Projectile.tscn")

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapon_marker: Marker2D = $WeaponMarker


func _ready() -> void:
	add_to_group("player")
	current_hearts = max_hearts
	EventBus.player_health_changed.emit(current_hearts, max_hearts)
	anim_sprite.sprite_frames = AnimSheetLoader.build_player_frames()
	anim_sprite.play("idle_down")


func _physics_process(delta: float) -> void:
	var move_vec := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if move_vec.length() > 1.0:
		move_vec = move_vec.normalized()
	
	if knockback_velocity.length() > 1.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_recovery_speed * delta)
	else:
		knockback_velocity = Vector2.ZERO
		velocity = move_vec * move_speed

	move_and_slide()

	var aim_vec := Vector2(
		Input.get_axis("shoot_left", "shoot_right"),
		Input.get_axis("shoot_up", "shoot_down")
	)
	var is_shooting := aim_vec.length() > 0.0

	if shoot_cooldown > 0.0:
		shoot_cooldown = max(shoot_cooldown - delta, 0.0)

	if shoot_timer > 0.0:
		shoot_timer = max(shoot_timer - delta, 0.0)

	if is_shooting:
		_face_towards(aim_vec.normalized())
		if shoot_cooldown <= 0.0:
			_shoot(aim_vec.normalized())
	elif shoot_timer <= 0.0:
		_update_facing(move_vec)

	_update_animation(move_vec, is_shooting)


func _update_facing(move_vec: Vector2) -> void:
	if move_vec.length() == 0.0:
		return
	_face_towards(move_vec)


func _face_towards(dir: Vector2) -> void:
	var effective_dir := -dir if reversed_facing else dir
	if abs(effective_dir.x) > abs(effective_dir.y):
		facing = Facing.SIDE
		facing_flip = effective_dir.x < 0
	else:
		facing = Facing.UP if effective_dir.y < 0 else Facing.DOWN


func _update_animation(move_vec: Vector2, is_shooting: bool) -> void:
	anim_sprite.flip_h = facing_flip
	var dir_suffix := _facing_suffix()

	if shoot_timer > 0.0 or is_shooting:
		if move_vec.length() > 0:
			anim_sprite.play("shoot_run_%s" % dir_suffix)
		else:
			anim_sprite.play("shoot_idle_%s" % dir_suffix)
	elif move_vec.length() > 0.0:
		anim_sprite.play("run_%s" % dir_suffix)
	else:
		anim_sprite.play("idle_%s" % dir_suffix)


func _facing_suffix() -> String:
	match facing:
		Facing.DOWN: return "down"
		Facing.UP: return "up"
		Facing.SIDE: return "side"
	return "down"

func get_effective_damage() -> float:
	var scaling_input: float = max(0.0, damage_ups * 1.2 + 1.0)
	return max(0.5, base_damage * sqrt(scaling_input))


func _shoot(aim_dir: Vector2) -> void:
	shoot_cooldown = fire_rate
	shoot_timer = PIERCE_DURATION

	var projectile := PROJECTILE_SCENE.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = weapon_marker.global_position + aim_dir * 10
	projectile.damage = get_effective_damage()
	projectile.launch(aim_dir, velocity)
	
func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO, knockback_strength: float = 0.0) -> void:
	if invulnerable or is_dying:
		return
	current_hearts -= amount
	EventBus.player_health_changed.emit(current_hearts, max_hearts)
	print("Player health", current_hearts)
	if current_hearts <= 0:
		_die()
	else:
		_start_invulnerability()
		if knockback_strength > 0.0 and not knockback_immune:
			knockback_velocity = knockback_dir.normalized() * knockback_strength

func _start_invulnerability() -> void:
	invulnerable = true
	var tween := create_tween()
	tween.set_loops(5)
	tween.tween_property(anim_sprite, "modulate:a", 0.3, 0.1)
	tween.tween_property(anim_sprite, "modulate:a", 1.0, 0.1)
	await get_tree().create_timer(INVULN_DURATION).timeout
	invulnerable = false
	anim_sprite.modulate.a = 1.0

func _die() -> void:
	if is_dying:
		return
	is_dying = true

	set_physics_process(false)
	velocity = Vector2.ZERO

	var dir_suffix := _facing_suffix()
	anim_sprite.play("player_death_%s" % dir_suffix)
	await anim_sprite.animation_finished

	print("Player died - restarting run")
	get_tree().reload_current_scene()

func add_item(item: Item) -> void:
	items.append(item)
	item.apply(self)
	EventBus.item_added.emit(item)
