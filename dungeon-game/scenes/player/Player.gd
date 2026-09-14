extends CharacterBody2D
class_name Player

# --- Movement ---
@export var move_speed: float = 100.0
var knockback_velocity: Vector2 = Vector2.ZERO
@export var knockback_recovery_speed: float = 800.0
@export var knockback_immune: bool = false

# --- Health ---
@export var max_hearts: int = 3
var current_hearts: int
var invulnerable: bool = false
const INVULN_DURATION := 1.0
var is_dying: bool = false

# --- Facing / animation ---
enum Facing { DOWN, UP, SIDE }
var facing: Facing = Facing.DOWN
var facing_flip: bool = false  # true = facing left
@export var reversed_facing: bool = true  # permanent design choice: character faces/shoots opposite its movement direction
var last_aim_dir: Vector2 = Vector2(0, 1)       # visual/reversed facing direction — used for sprite orientation only
var last_true_aim_dir: Vector2 = Vector2(0, 1)  # RAW aim direction — used by anything that should fire where you're actually aiming (lasers, etc.)

# --- Shooting ---
@export var fire_rate: float = 0.55  # seconds between shots while holding a direction
@export var allow_diagonal_shooting: bool = false
var shoot_timer: float = 0.0
var shoot_cooldown: float = 0.0
const PIERCE_DURATION := 0.2
const PROJECTILE_SCENE := preload("res://scenes/player/Projectile.tscn")

# --- Damage scaling (Isaac-style diminishing returns) ---
@export var base_damage: float = 3.5
var damage_ups: int = 0

# --- Weapon composition: shot_style REPLACES (laser vs. projectile, etc.),
# shot_pattern_modifiers STACKS (double-shot, future patterns). Both combine
# inside fire_single_shot() without knowing about each other. ---
var shot_style: ShotStyleModifier = null
var shot_pattern_modifiers: Array[ShotPatternModifier] = []
@onready var laser_ray: RayCast2D = $LaserRay

# --- Passive items ---
var damage_ups_items: Array[Item] = []  # NOTE: see below, renamed from `items` — see comment
var items: Array[Item] = []

# --- Active item (Space-triggered) ---
var active_item: ActiveItem = null
var active_item_cooldown_timer: float = 0.0

# --- Orbitals ---
var orbitals: Array[Node2D] = []
var orbital_rotation: float = 0.0
@export var orbital_rotation_speed_deg: float = 90.0

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

	orbital_rotation += deg_to_rad(orbital_rotation_speed_deg) * delta
	move_and_slide()

	var aim_vec := Vector2(
		Input.get_axis("shoot_left", "shoot_right"),
		Input.get_axis("shoot_up", "shoot_down")
	)
	if not allow_diagonal_shooting and aim_vec.x != 0.0 and aim_vec.y != 0.0:
		if abs(aim_vec.x) >= abs(aim_vec.y):
			aim_vec.y = 0.0
		else:
			aim_vec.x = 0.0

	var is_shooting := aim_vec.length() > 0.0

	if shoot_cooldown > 0.0:
		shoot_cooldown = max(shoot_cooldown - delta, 0.0)
	if shoot_timer > 0.0:
		shoot_timer = max(shoot_timer - delta, 0.0)

	if is_shooting:
		var normalized_aim: Vector2 = aim_vec.normalized()
		_face_towards(normalized_aim)
		if shoot_cooldown <= 0.0:
			_shoot(normalized_aim)
	elif shoot_timer <= 0.0:
		_update_facing(move_vec)

	if active_item_cooldown_timer > 0.0:
		active_item_cooldown_timer = max(active_item_cooldown_timer - delta, 0.0)
	if Input.is_action_just_pressed("use_active_item") and active_item and active_item_cooldown_timer <= 0.0:
		shoot_timer = PIERCE_DURATION
		active_item.effect.activate(self)
		active_item_cooldown_timer = active_item.cooldown

	_update_animation(move_vec, is_shooting)


func _update_facing(move_vec: Vector2) -> void:
	if move_vec.length() == 0.0:
		return
	_face_towards(move_vec)


func _face_towards(dir: Vector2) -> void:
	last_true_aim_dir = dir.normalized()
	var effective_dir := -dir if reversed_facing else dir
	last_aim_dir = effective_dir.normalized()
	if abs(effective_dir.x) > abs(effective_dir.y):
		facing = Facing.SIDE
		facing_flip = effective_dir.x < 0
	else:
		facing = Facing.UP if effective_dir.y < 0 else Facing.DOWN


func _update_animation(move_vec: Vector2, is_shooting: bool) -> void:
	anim_sprite.flip_h = facing_flip
	var dir_suffix := _facing_suffix()

	if shoot_timer > 0.0 or is_shooting:
		anim_sprite.play("shoot_run_%s" % dir_suffix if move_vec.length() > 0 else "shoot_idle_%s" % dir_suffix)
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


## Isaac-style diminishing returns: each successive +1 damage_ups is worth
## progressively less. Floored at 0.5 so a heavily negative-damage build can
## never fully brick the player's ability to deal damage.
func get_effective_damage() -> float:
	var scaling_input: float = max(0.0, damage_ups * 1.2 + 1.0)
	return max(0.5, base_damage * sqrt(scaling_input))


func _shoot(aim_dir: Vector2) -> void:
	shoot_cooldown = fire_rate
	shoot_timer = PIERCE_DURATION
	fire_single_shot(aim_dir)


## Single chokepoint every shot source (regular fire, RadialBurstEffect, any
## future multi-shot effect) routes through. shot_pattern_modifiers expand one
## direction into several; shot_style decides what each resulting shot IS.
## Neither piece needs to know the other exists — see ShotStyleModifier /
## ShotPatternModifier for why this composes freely.
func fire_single_shot(base_dir: Vector2, apply_momentum: bool = true) -> void:
	var dirs: Array[Vector2] = [base_dir]
	for modifier in shot_pattern_modifiers:
		dirs = modifier.modify_directions(dirs)

	for d in dirs:
		if shot_style:
			shot_style.fire(self, d, apply_momentum)
		else:
			_fire_projectile(d, apply_momentum)


func _fire_projectile(aim_dir: Vector2, apply_momentum: bool = true) -> void:
	var projectile := PROJECTILE_SCENE.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = weapon_marker.global_position + aim_dir * 10
	projectile.damage = get_effective_damage()
	var shooter_velocity: Vector2 = velocity if apply_momentum else Vector2.ZERO
	projectile.launch(aim_dir, shooter_velocity)


func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, knockback_strength: float = 0.0) -> void:
	if invulnerable or is_dying:
		return
	current_hearts -= int(round(amount))
	EventBus.player_health_changed.emit(current_hearts, max_hearts)
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

	get_tree().reload_current_scene()


func add_item(item: Item) -> void:
	items.append(item)
	item.apply(self)
	EventBus.item_added.emit(item)


func add_active_item(item: ActiveItem) -> void:
	active_item = item
	active_item_cooldown_timer = 0.0
	EventBus.active_item_changed.emit(item)


func add_orbital(scene: PackedScene) -> void:
	var orbital := scene.instantiate()
	call_deferred("add_child", orbital)
	orbitals.append(orbital)
	call_deferred("_recalculate_orbital_spacing")


func _recalculate_orbital_spacing() -> void:
	var count := orbitals.size()
	for i in count:
		orbitals[i].angle_offset = TAU * float(i) / float(count)
