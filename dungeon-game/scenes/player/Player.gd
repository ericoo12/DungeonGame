extends CharacterBody2D
class_name Player

# --- Movement ---
@export var move_speed: float = 100.0
var knockback_velocity: Vector2 = Vector2.ZERO
@export var knockback_recovery_speed: float = 800.0
@export var knockback_immune: bool = false
@onready var camera: Camera2D = $Camera2D

# --- Health ---
@export var max_hearts: int = 3
var current_hearts: int
var invulnerable: bool = false
const INVULN_DURATION := 1.0
var is_dying: bool = false

# --- Player size (scales sprite + collisions together) ---
@export var player_scale: float = 0.015
@onready var hurtbox: Area2D = $HurtBox
@onready var body_collision: CollisionShape2D = $wallCollision
@onready var hurtbox_collision: CollisionShape2D = $HurtBox/EnemyCollision
const PLAYER_SIZE_MIN := 0.0001
const PLAYER_SIZE_MAX := 2.0
@onready var lower_sprite: AnimatedSprite2D = $LowerBodySprite
@onready var upper_sprite: AnimatedSprite2D = $UpperBodySprite
var body_collision_base_position: Vector2 = Vector2.ZERO
var hurtbox_collision_base_position: Vector2 = Vector2.ZERO
var hurtbox_base_position: Vector2 = Vector2.ZERO
# --- Shadow ---
const SHADOW_SCENE := preload("res://scenes/effects/Shadow.tscn")

# --- Facing / animation ---
enum Facing { DOWN, LEFT, RIGHT, UP }
var facing: Facing = Facing.DOWN
var last_aim_dir: Vector2 = Vector2.DOWN       # direction the character is currently facing
var last_true_aim_dir: Vector2 = Vector2.DOWN  # actual shooting direction, kept separate for other weapons/effects

# --- Shooting ---
@export var fire_rate: float = 0.55
@export var allow_diagonal_shooting: bool = false
var shoot_timer: float = 0.0
var shoot_cooldown: float = 0.0
const SHOOT_POSE_DURATION := 0.33  # Captain Filling's throw animation: 5 frames @ 10 FPS ≈ 0.5s
const PROJECTILE_SCENE := preload("res://scenes/player/Projectile.tscn")

# --- Projectile modifiers ---
@export var projectile_knockback: float = 100.0
@export var projectile_range: float = 1.0
@export var projectile_size: float = 1.0
const KNOCKBACK_MIN := 0.0
const KNOCKBACK_MAX := 500.0
const RANGE_MIN := 0.3
const RANGE_MAX := 4.0
const PROJECTILE_SIZE_MIN := 0.3
const PROJECTILE_SIZE_MAX := 3.0

# --- Damage ---
@export var base_damage: float = 3.5
var damage_ups: int = 0

# --- Weapon composition ---
var shot_style: ShotStyleModifier = null
var shot_pattern_modifiers: Array[ShotPatternModifier] = []


# --- Passive items ---
var damage_ups_items: Array[Item] = []
var items: Array[Item] = []

# --- Active item ---
var active_item: ActiveItem = null
var active_item_cooldown_timer: float = 0.0

# --- Orbitals ---
var orbitals: Array[Node2D] = []
var orbital_rotation: float = 0.0
@export var orbital_rotation_speed_deg: float = 90.0

# --- Followers ---
var followers: Array[Node2D] = []
var position_history: Array = []
const MAX_HISTORY_AGE := 3.0

# --- Nodes ---
@onready var weapon_marker: Marker2D = $WeaponMarker
@onready var laser_ray: RayCast2D = $LaserRay

const UPPER_ANIM_TRANSFORM := {
	"idle_down":   {"scale": 1.0, "offset": Vector2(-5.0, -5.0)},
	"attack_down": {"scale": 0.9, "offset": Vector2(-10.0, 5.0)},
	
	"idle_left":   {"scale": 1.0, "offset": Vector2(0.0, 5.0)},
	"attack_left": {"scale": 1.0, "offset": Vector2(-15.0, 15.0)},
	
	"idle_right":  {"scale": 1.0, "offset": Vector2(-15.0, 5.0)},
	"attack_right":{"scale": 1.0, "offset": Vector2(0.0, 15.0)},
	
	"idle_up":     {"scale": 1.0, "offset": Vector2(-5.0, 0.0)},
	"attack_up":   {"scale": 0.9, "offset": Vector2(-10.0, 0.0)},
}

const LOWER_ANIM_TRANSFORM := {
	"idle_down": {"scale": 1.0, "offset": Vector2.ZERO},
	"run_down":  {"scale": 1.0, "offset": Vector2.ZERO},
	
	"idle_left": {"scale": 1.0, "offset": Vector2.ZERO},
	"run_left":  {"scale": 1.0, "offset": Vector2(5.0, 0.0)},
	
	"idle_right": {"scale": 1.0, "offset": Vector2.ZERO},
	"run_right":  {"scale": 1.0, "offset": Vector2(-5.0, 0.0)},
	
	"idle_up":   {"scale": 1.0, "offset": Vector2.ZERO},
	"run_up":    {"scale": 1.0, "offset": Vector2(0.0, 0.0)},  # run_up's legs extend ~27px higher than idle_up — shift down to compensate
}

var lower_base_position: Vector2 = Vector2.ZERO  # set once in _ready(), same pattern as upper_base_position

var upper_base_position: Vector2 = Vector2.ZERO  


func _ready() -> void:
	add_to_group("player")
	body_collision_base_position = body_collision.position
	hurtbox_collision_base_position = hurtbox_collision.position
	hurtbox_base_position = hurtbox.position
	set_player_scale(player_scale)
	current_hearts = max_hearts
	EventBus.player_health_changed.emit(current_hearts, max_hearts)

	var body_frames: Dictionary = AnimSheetLoader.build_layered_body_frames()

	lower_sprite.sprite_frames = body_frames.lower
	upper_sprite.sprite_frames = body_frames.upper
	upper_base_position = upper_sprite.position
	lower_base_position = lower_sprite.position

	lower_sprite.play("idle_down")
	upper_sprite.play("idle_down")

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
		var normalized_aim := aim_vec.normalized()
		_face_towards(normalized_aim)  # Captain Filling faces the same direction he's shooting
		if shoot_cooldown <= 0.0:
			_shoot(normalized_aim, move_vec.length() > 0.0)
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
	# Movement can be diagonal, but Captain Filling only has 4 sprite directions.
	if clamped_dir.x != 0.0 and clamped_dir.y != 0.0:
		if abs(clamped_dir.x) >= abs(clamped_dir.y):
			clamped_dir.y = 0.0
		else:
			clamped_dir.x = 0.0

	_face_towards(clamped_dir)


func _face_towards(dir: Vector2) -> void:
	if dir.length_squared() <= 0.0:
		return

	var normalized_dir := dir.normalized()
	last_true_aim_dir = normalized_dir
	last_aim_dir = normalized_dir

	if abs(normalized_dir.x) > abs(normalized_dir.y):
		facing = Facing.LEFT if normalized_dir.x < 0.0 else Facing.RIGHT
	else:
		facing = Facing.UP if normalized_dir.y < 0.0 else Facing.DOWN


func _update_animation(move_vec: Vector2, is_shooting: bool) -> void:
	var dir_suffix := _facing_suffix()
	var flip := (facing == Facing.RIGHT)
	var anim_dir := dir_suffix
	var frame_dir := "left" if facing == Facing.RIGHT else dir_suffix

	lower_sprite.flip_h = flip
	upper_sprite.flip_h = flip

	var lower_frame_name: String = ("run_" if move_vec.length() > 0.0 else "idle_") + frame_dir
	lower_sprite.play(lower_frame_name)

	var lower_transform_key: String = ("run_" if move_vec.length() > 0.0 else "idle_") + anim_dir
	var lower_transform: Dictionary = LOWER_ANIM_TRANSFORM.get(lower_transform_key, {"scale": 1.0, "offset": Vector2.ZERO})
	lower_sprite.scale = Vector2.ONE * player_scale * lower_transform.scale
	lower_sprite.position = (lower_base_position + lower_transform.offset) * player_scale

	var upper_state: String = "attack" if (shoot_timer > 0.0 or is_shooting) else "idle"
	var upper_frame_name: String = upper_state + "_" + frame_dir
	if not upper_sprite.sprite_frames.has_animation(upper_frame_name):
		upper_frame_name = "idle_" + frame_dir
	upper_sprite.play(upper_frame_name)

	var upper_transform_key: String = upper_state + "_" + anim_dir
	var upper_transform: Dictionary = UPPER_ANIM_TRANSFORM.get(upper_transform_key, {"scale": 1.0, "offset": Vector2.ZERO})
	upper_sprite.scale = Vector2.ONE * player_scale * upper_transform.scale
	upper_sprite.position = (upper_base_position + upper_transform.offset) * player_scale


func _facing_suffix() -> String:
	match facing:
		Facing.DOWN: return "down"
		Facing.LEFT: return "left"
		Facing.RIGHT: return "right"  # now returns the real direction — mirroring is handled separately in _update_animation()
		Facing.UP: return "up"
	return "down"


func get_effective_damage() -> float:
	var scaling_input: float = max(0.0, damage_ups * 1.2 + 1.0)
	return max(0.5, base_damage * sqrt(scaling_input))


func _shoot(aim_dir: Vector2, is_moving: bool) -> void:
	shoot_cooldown = fire_rate
	shoot_timer = SHOOT_POSE_DURATION
	fire_single_shot(aim_dir)


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
	tween.tween_property(lower_sprite, "modulate:a", 0.3, 0.1)
	tween.parallel().tween_property(upper_sprite, "modulate:a", 0.3, 0.1)
	tween.tween_property(lower_sprite, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(upper_sprite, "modulate:a", 1.0, 0.1)
	await get_tree().create_timer(INVULN_DURATION).timeout
	invulnerable = false
	lower_sprite.modulate.a = 1.0
	upper_sprite.modulate.a = 1.0


func _die() -> void:
	if is_dying:
		return
	is_dying = true

	set_physics_process(false)
	velocity = Vector2.ZERO

	lower_sprite.stop()
	upper_sprite.stop()
	await get_tree().create_timer(0.5).timeout
	GameState.reset()
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
	lower_sprite.scale = Vector2.ONE * player_scale
	upper_sprite.scale = Vector2.ONE * player_scale
	body_collision.scale = Vector2.ONE * player_scale
	hurtbox_collision.scale = Vector2.ONE * player_scale
	body_collision.position = body_collision_base_position * player_scale
	hurtbox_collision.position = hurtbox_collision_base_position * player_scale
	hurtbox.position = hurtbox_base_position * player_scale


func equip_shot_style(style: ShotStyleModifier) -> void:
	shot_style = style.duplicate()
	resync_shot_style()


func resync_shot_style() -> void:
	if shot_style:
		shot_style.apply_player_stats(self)


func _record_position_history() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	position_history.append({"time": now, "pos": global_position})
	while position_history.size() > 0 and now - position_history[0].time > MAX_HISTORY_AGE:
		position_history.pop_front()


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
	get_parent().add_child(follower)
	follower.setup(self, trail_delay)
	followers.append(follower)


func _spawn_shadow() -> void:
	var shadow: Shadow = SHADOW_SCENE.instantiate()
	var ground_layer := get_tree().get_first_node_in_group("ground_effects")
	var target_parent: Node = ground_layer if ground_layer else get_parent()
	target_parent.add_child(shadow)
	shadow.setup(self, false)


func set_camera_bounds(room_center: Vector2, room_size: Vector2) -> void:
	var half_size: Vector2 = room_size / 2.0
	camera.limit_left = int(room_center.x - half_size.x)
	camera.limit_right = int(room_center.x + half_size.x)
	camera.limit_top = int(room_center.y - half_size.y)
	camera.limit_bottom = int(room_center.y + half_size.y)
	camera.reset_smoothing()


func reset_position_history() -> void:
	position_history.clear()


func reset_followers_position() -> void:
	for follower in followers:
		if is_instance_valid(follower):
			follower.global_position = global_position
