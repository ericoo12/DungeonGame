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

# --- Player body size — scales the whole node, so sprite AND every collision
# shape (movement body, Hurtbox) grow/shrink together automatically. ---
@export var player_scale: float = 1.0
@onready var body_collision: CollisionShape2D = $wallCollision
@onready var hurtbox_collision: CollisionShape2D = $HurtBox/EnemyCollision
const PLAYER_SIZE_MIN := 0.5
const PLAYER_SIZE_MAX := 2.0

# --- shadow ---
const SHADOW_SCENE := preload("res://scenes/effects/Shadow.tscn")

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
const SHOOT_POSE_DURATION := 0.2
const PROJECTILE_SCENE := preload("res://scenes/player/Projectile.tscn")

# --- Projectile modifiers (applied to every regualr shot)
@export var projectile_knockback: float = 100.0
@export var projectile_range: float = 1.0
@export var projectile_size: float = 1.0

const KNOCKBACK_MIN := 0.0
const KNOCKBACK_MAX := 500.0
const RANGE_MIN := 0.3
const RANGE_MAX := 4.0
const PROJECTILE_SIZE_MIN := 0.3
const PROJECTILE_SIZE_MAX := 3.0

# --- Damage scaling ) ---
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

# --- Trailing followers ---
var followers: Array[Node2D] = []
var position_history: Array = []
const MAX_HISTORY_AGE := 3.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapon_marker: Marker2D = $WeaponMarker


func _ready() -> void:
	add_to_group("player")
	set_player_scale(player_scale)
	current_hearts = max_hearts
	EventBus.player_health_changed.emit(current_hearts, max_hearts)
	anim_sprite.sprite_frames = AnimSheetLoader.build_player_frames()
	anim_sprite.play("idle_down")
	_spawn_shadow()


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
	_record_position_history()
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
		shoot_timer = SHOOT_POSE_DURATION
		active_item.effect.activate(self)
		active_item_cooldown_timer = active_item.cooldown

	_update_animation(move_vec, is_shooting)


func _update_facing(move_vec: Vector2) -> void:
	if move_vec.length() == 0.0:
		return
	var clamped_dir := move_vec
	if not allow_diagonal_shooting and clamped_dir.x != 0.0 and clamped_dir.y != 0.0:
		if abs(clamped_dir.x) >= abs(clamped_dir.y):
			clamped_dir.y = 0.0
		else:
			clamped_dir.x = 0.0
	_face_towards(clamped_dir)


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


## diminishing returns: each successive +1 damage_ups is worth
## progressively less. Floored at 0.5 so a heavily negative-damage build can
## never fully brick the player's ability to deal damage.
func get_effective_damage() -> float:
	var scaling_input: float = max(0.0, damage_ups * 1.2 + 1.0)
	return max(0.5, base_damage * sqrt(scaling_input))


func _shoot(aim_dir: Vector2) -> void:
	shoot_cooldown = fire_rate
	shoot_timer = SHOOT_POSE_DURATION
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
	print("modifiers: ", shot_pattern_modifiers.size(), "  dirs: ", dirs.size())
	for d in dirs:
		if shot_style:
			shot_style.fire(self, d, apply_momentum)
		else:
			_fire_projectile(d, apply_momentum)


func _fire_projectile(aim_dir: Vector2, apply_momentum: bool = true) -> void:
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.damage = get_effective_damage()
	projectile.knockback_strength = projectile_knockback
	projectile.lifetime = projectile_range
	projectile.scale = Vector2.ONE * projectile_size
	
	get_parent().add_child(projectile)
	projectile.global_position = weapon_marker.global_position + aim_dir * 10
	
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
		


func set_player_scale(value: float) -> void:
	player_scale = clamp(value, PLAYER_SIZE_MIN, PLAYER_SIZE_MAX)
	anim_sprite.scale = Vector2.ONE * player_scale
	body_collision.scale = Vector2.ONE * player_scale
	hurtbox_collision.scale = Vector2.ONE * player_scale


func equip_shot_style(style: ShotStyleModifier) -> void:
	shot_style = style.duplicate()
	resync_shot_style()


## Re-applies current stats to whatever shot_style is equipped. Call this
## whenever a range/size/knockback-affecting item is picked up, not just when
## the weapon itself is first equipped — otherwise a laser equipped BEFORE a
## range item wouldn't benefit from it.
func resync_shot_style() -> void:
	if shot_style:
		shot_style.apply_player_stats(self)


func _record_position_history() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	position_history.append({"time": now, "pos": global_position})
	while position_history.size() > 0 and now - position_history[0].time > MAX_HISTORY_AGE:
		position_history.pop_front()


## Returns where the player WAS `delay` seconds ago, interpolated between the
## two nearest recorded samples. Falls back to `fallback` if there's not
## enough history yet (e.g. right after spawning a new follower).
func get_trailing_position(delay: float, fallback: Vector2) -> Vector2:
	if position_history.is_empty():
		return fallback

	var target_time: float = Time.get_ticks_msec() / 1000.0 - delay
	if target_time <= position_history[0].time:
		return position_history[0].pos

	for i in range(position_history.size() - 1):
		var a: Dictionary = position_history[i]
		var b: Dictionary = position_history[i + 1]
		if a.time <= target_time and target_time <= b.time:
			var t: float = (target_time - a.time) / max(b.time - a.time, 0.0001)
			return a.pos.lerp(b.pos, t)

	return position_history[-1].pos


func add_follower(scene: PackedScene, trail_delay: float) -> void:
	var follower := scene.instantiate()
	get_parent().add_child(follower)  # sibling of Player, not a child — must NOT inherit player_scale/rotation
	follower.setup(self, trail_delay)
	followers.append(follower)


func _spawn_shadow() -> void:
	var shadow: Shadow = SHADOW_SCENE.instantiate()
	var ground_layer := get_tree().get_first_node_in_group("ground_effects")
	var target_parent: Node = ground_layer if ground_layer else get_parent()
	target_parent.add_child(shadow)
	shadow.setup(self, false)
