extends CharacterBody2D
class_name Player


# ============================================================
# MOVEMENT
# ============================================================

@export var move_speed: float = 100.0

var knockback_velocity: Vector2 = Vector2.ZERO

@export var knockback_recovery_speed: float = 800.0
@export var knockback_immune: bool = false

@onready var camera: Camera2D = $Camera2D


# ============================================================
# HEALTH
# ============================================================

@export var max_hearts: int = 3

var current_hearts: int
var invulnerable: bool = false

const INVULN_DURATION := 1.0

var is_dying: bool = false


# ============================================================
# PLAYER SIZE
# ============================================================

# Scales the whole player setup:
# sprite + collisions.

@export var player_scale: float = 0.1

@onready var body_collision: CollisionShape2D = $wallCollision
@onready var hurtbox_collision: CollisionShape2D = $HurtBox/EnemyCollision

const PLAYER_SIZE_MIN := 0.1
const PLAYER_SIZE_MAX := 2.0


# ============================================================
# SHADOW
# ============================================================

const SHADOW_SCENE := preload(
	"res://scenes/effects/Shadow.tscn"
)


# ============================================================
# FACING / ANIMATION
# ============================================================

enum Facing {
	DOWN,
	LEFT,
	RIGHT,
	UP
}

var facing: Facing = Facing.DOWN


# Direction the character is currently facing.
var last_aim_dir: Vector2 = Vector2.DOWN


# Actual shooting direction.
# Kept separately because other weapons/effects may use it.
var last_true_aim_dir: Vector2 = Vector2.DOWN


# ============================================================
# SHOOTING
# ============================================================

@export var fire_rate: float = 0.55

@export var allow_diagonal_shooting: bool = false

var shoot_timer: float = 0.0
var shoot_cooldown: float = 0.0


# Captain Filling's throw animation is 5 frames at 10 FPS,
# so roughly 0.5 seconds.
const SHOOT_POSE_DURATION := 0.5


const PROJECTILE_SCENE := preload(
	"res://scenes/player/Projectile.tscn"
)


# ============================================================
# PROJECTILE MODIFIERS
# ============================================================

@export var projectile_knockback: float = 100.0
@export var projectile_range: float = 1.0
@export var projectile_size: float = 1.0


const KNOCKBACK_MIN := 0.0
const KNOCKBACK_MAX := 500.0

const RANGE_MIN := 0.3
const RANGE_MAX := 4.0

const PROJECTILE_SIZE_MIN := 0.3
const PROJECTILE_SIZE_MAX := 3.0


# ============================================================
# DAMAGE
# ============================================================

@export var base_damage: float = 3.5

var damage_ups: int = 0


# ============================================================
# WEAPON COMPOSITION
# ============================================================

var shot_style: ShotStyleModifier = null

var shot_pattern_modifiers: Array[ShotPatternModifier] = []

@onready var laser_ray: RayCast2D = $LaserRay


# ============================================================
# PASSIVE ITEMS
# ============================================================

var damage_ups_items: Array[Item] = []

var items: Array[Item] = []


# ============================================================
# ACTIVE ITEM
# ============================================================

var active_item: ActiveItem = null

var active_item_cooldown_timer: float = 0.0


# ============================================================
# ORBITALS
# ============================================================

var orbitals: Array[Node2D] = []

var orbital_rotation: float = 0.0

@export var orbital_rotation_speed_deg: float = 90.0


# ============================================================
# FOLLOWERS
# ============================================================

var followers: Array[Node2D] = []

var position_history: Array = []

const MAX_HISTORY_AGE := 3.0


# ============================================================
# NODES
# ============================================================

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var weapon_marker: Marker2D = $WeaponMarker


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	add_to_group("player")

	set_player_scale(player_scale)

	current_hearts = max_hearts

	EventBus.player_health_changed.emit(
		current_hearts,
		max_hearts
	)


	# Captain Filling sprite sheets
	anim_sprite.sprite_frames = (
		AnimSheetLoader.build_player_frames()
	)


	# We have actual LEFT and RIGHT animations now.
	# Never flip the sprite.
	anim_sprite.flip_h = false


	anim_sprite.play("idle_down")


	_spawn_shadow()


# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:

	# --------------------------------------------------------
	# MOVEMENT INPUT
	# --------------------------------------------------------

	var move_vec := Vector2(
		Input.get_axis(
			"move_left",
			"move_right"
		),
		Input.get_axis(
			"move_up",
			"move_down"
		)
	)


	if move_vec.length() > 1.0:
		move_vec = move_vec.normalized()


	# --------------------------------------------------------
	# KNOCKBACK / MOVEMENT
	# --------------------------------------------------------

	if knockback_velocity.length() > 1.0:

		velocity = knockback_velocity

		knockback_velocity = (
			knockback_velocity.move_toward(
				Vector2.ZERO,
				knockback_recovery_speed * delta
			)
		)

	else:

		knockback_velocity = Vector2.ZERO

		velocity = move_vec * move_speed


	# --------------------------------------------------------
	# ORBITALS
	# --------------------------------------------------------

	orbital_rotation += (
		deg_to_rad(orbital_rotation_speed_deg)
		* delta
	)


	# --------------------------------------------------------
	# MOVE
	# --------------------------------------------------------

	move_and_slide()


	_record_position_history()


	# --------------------------------------------------------
	# AIM INPUT
	# --------------------------------------------------------

	var aim_vec := Vector2(
		Input.get_axis(
			"shoot_left",
			"shoot_right"
		),
		Input.get_axis(
			"shoot_up",
			"shoot_down"
		)
	)


	# --------------------------------------------------------
	# NO DIAGONAL SHOOTING
	# --------------------------------------------------------

	if (
		not allow_diagonal_shooting
		and aim_vec.x != 0.0
		and aim_vec.y != 0.0
	):

		if abs(aim_vec.x) >= abs(aim_vec.y):

			aim_vec.y = 0.0

		else:

			aim_vec.x = 0.0


	var is_shooting := aim_vec.length() > 0.0


	# --------------------------------------------------------
	# SHOOTING TIMERS
	# --------------------------------------------------------

	if shoot_cooldown > 0.0:

		shoot_cooldown = max(
			shoot_cooldown - delta,
			0.0
		)


	if shoot_timer > 0.0:

		shoot_timer = max(
			shoot_timer - delta,
			0.0
		)


	# --------------------------------------------------------
	# AIM / SHOOT
	# --------------------------------------------------------

	if is_shooting:

		var normalized_aim := aim_vec.normalized()


		# Captain Filling faces the SAME direction
		# that he is actually shooting.
		_face_towards(normalized_aim)


		if shoot_cooldown <= 0.0:

			_shoot(
				normalized_aim,
				move_vec.length() > 0.0
			)


	# --------------------------------------------------------
	# FACE MOVEMENT DIRECTION
	# --------------------------------------------------------

	elif shoot_timer <= 0.0:

		_update_facing(move_vec)


	# --------------------------------------------------------
	# ACTIVE ITEM
	# --------------------------------------------------------

	if active_item_cooldown_timer > 0.0:

		active_item_cooldown_timer = max(
			active_item_cooldown_timer - delta,
			0.0
		)


	if (
		Input.is_action_just_pressed(
			"use_active_item"
		)
		and active_item
		and active_item_cooldown_timer <= 0.0
	):

		shoot_timer = SHOOT_POSE_DURATION

		active_item.effect.activate(self)

		active_item_cooldown_timer = (
			active_item.cooldown
		)


	# --------------------------------------------------------
	# ANIMATION
	# --------------------------------------------------------

	_update_animation(
		move_vec,
		is_shooting
	)


# ============================================================
# UPDATE FACING FROM MOVEMENT
# ============================================================

func _update_facing(move_vec: Vector2) -> void:

	if move_vec.length() == 0.0:
		return


	var clamped_dir := move_vec


	# Even though movement can technically be diagonal,
	# Captain Filling only has 4 sprite directions.

	if (
		clamped_dir.x != 0.0
		and clamped_dir.y != 0.0
	):

		if abs(clamped_dir.x) >= abs(clamped_dir.y):

			clamped_dir.y = 0.0

		else:

			clamped_dir.x = 0.0


	_face_towards(clamped_dir)


# ============================================================
# FACE DIRECTION
# ============================================================

func _face_towards(dir: Vector2) -> void:

	if dir.length_squared() <= 0.0:
		return


	var normalized_dir := dir.normalized()


	last_true_aim_dir = normalized_dir
	last_aim_dir = normalized_dir


	# Horizontal direction dominates.
	if abs(normalized_dir.x) > abs(normalized_dir.y):

		if normalized_dir.x < 0.0:

			facing = Facing.LEFT

		else:

			facing = Facing.RIGHT


	# Vertical direction dominates.
	else:

		if normalized_dir.y < 0.0:

			facing = Facing.UP

		else:

			facing = Facing.DOWN


# ============================================================
# ANIMATION
# ============================================================

func _update_animation(
	move_vec: Vector2,
	is_shooting: bool
) -> void:

	var dir_suffix := _facing_suffix()

	var animation_name: String


	# --------------------------------------------------------
	# THROWING
	# --------------------------------------------------------

	if shoot_timer > 0.0 or is_shooting:

		if move_vec.length() > 0.0:

			animation_name = (
				"throw_run_"
				+ dir_suffix
			)

		else:

			animation_name = (
				"throw_idle_"
				+ dir_suffix
			)


	# --------------------------------------------------------
	# RUNNING
	# --------------------------------------------------------

	elif move_vec.length() > 0.0:

		animation_name = (
			"run_"
			+ dir_suffix
		)


	# --------------------------------------------------------
	# IDLE
	# --------------------------------------------------------

	else:

		animation_name = (
			"idle_"
			+ dir_suffix
		)


	# Don't restart the same animation every physics frame.
	if anim_sprite.animation != animation_name:

		anim_sprite.play(animation_name)


# ============================================================
# FACING STRING
# ============================================================

func _facing_suffix() -> String:

	match facing:

		Facing.DOWN:
			return "down"

		Facing.LEFT:
			return "left"

		Facing.RIGHT:
			return "right"

		Facing.UP:
			return "up"


	return "down"


# ============================================================
# DAMAGE CALCULATION
# ============================================================

func get_effective_damage() -> float:

	var scaling_input: float = max(
		0.0,
		damage_ups * 1.2 + 1.0
	)


	return max(
		0.5,
		base_damage * sqrt(scaling_input)
	)


# ============================================================
# SHOOT
# ============================================================

func _shoot(
	aim_dir: Vector2,
	is_moving: bool
) -> void:

	shoot_cooldown = fire_rate

	shoot_timer = SHOOT_POSE_DURATION


	# --------------------------------------------------------
	# Restart Captain Filling's throw animation
	# for every new shot.
	# --------------------------------------------------------

	var dir_suffix := _facing_suffix()

	var animation_name: String


	if is_moving:

		animation_name = (
			"throw_run_"
			+ dir_suffix
		)

	else:

		animation_name = (
			"throw_idle_"
			+ dir_suffix
		)


	anim_sprite.stop()
	anim_sprite.play(animation_name)


	# --------------------------------------------------------
	# FIRE
	# --------------------------------------------------------

	fire_single_shot(aim_dir)


# ============================================================
# FIRE SINGLE SHOT
# ============================================================

func fire_single_shot(
	base_dir: Vector2,
	apply_momentum: bool = true
) -> void:

	var dirs: Array[Vector2] = [
		base_dir
	]


	for modifier in shot_pattern_modifiers:

		dirs = modifier.modify_directions(
			dirs
		)


	for d in dirs:

		if shot_style:

			shot_style.fire(
				self,
				d,
				apply_momentum
			)

		else:

			_fire_projectile(
				d,
				apply_momentum
			)


# ============================================================
# PROJECTILE
# ============================================================

func _fire_projectile(
	aim_dir: Vector2,
	apply_momentum: bool = true
) -> void:

	var projectile := (
		PROJECTILE_SCENE.instantiate()
	)


	projectile.damage = (
		get_effective_damage()
	)


	projectile.knockback_strength = (
		projectile_knockback
	)


	projectile.lifetime = (
		projectile_range
	)


	projectile.scale = (
		Vector2.ONE
		* projectile_size
	)


	get_parent().add_child(
		projectile
	)


	projectile.global_position = (
		weapon_marker.global_position
		+ aim_dir * 10
	)


	var shooter_velocity: Vector2 = (
		velocity
		if apply_momentum
		else Vector2.ZERO
	)


	projectile.launch(
		aim_dir,
		shooter_velocity
	)


# ============================================================
# TAKE DAMAGE
# ============================================================

func take_damage(
	amount: float,
	knockback_dir: Vector2 = Vector2.ZERO,
	knockback_strength: float = 0.0
) -> void:

	if invulnerable or is_dying:
		return


	current_hearts -= int(
		round(amount)
	)


	EventBus.player_health_changed.emit(
		current_hearts,
		max_hearts
	)


	if current_hearts <= 0:

		_die()

	else:

		_start_invulnerability()


		if (
			knockback_strength > 0.0
			and not knockback_immune
		):

			knockback_velocity = (
				knockback_dir.normalized()
				* knockback_strength
			)


# ============================================================
# INVULNERABILITY
# ============================================================

func _start_invulnerability() -> void:

	invulnerable = true


	var tween := create_tween()

	tween.set_loops(5)


	tween.tween_property(
		anim_sprite,
		"modulate:a",
		0.3,
		0.1
	)


	tween.tween_property(
		anim_sprite,
		"modulate:a",
		1.0,
		0.1
	)


	await get_tree().create_timer(
		INVULN_DURATION
	).timeout


	invulnerable = false

	anim_sprite.modulate.a = 1.0


# ============================================================
# DEATH
# ============================================================

func _die() -> void:

	if is_dying:
		return


	is_dying = true


	set_physics_process(false)

	velocity = Vector2.ZERO


	# Captain Filling does not currently have a death sheet.
	# Freeze briefly, then restart room.

	anim_sprite.stop()


	await get_tree().create_timer(
		0.5
	).timeout


	get_tree().reload_current_scene()


# ============================================================
# ITEMS
# ============================================================

func add_item(item: Item) -> void:

	items.append(item)

	item.apply(self)

	EventBus.item_added.emit(item)


# ============================================================
# ACTIVE ITEMS
# ============================================================

func add_active_item(
	item: ActiveItem
) -> void:

	active_item = item

	active_item_cooldown_timer = 0.0

	EventBus.active_item_changed.emit(item)


# ============================================================
# ORBITALS
# ============================================================

func add_orbital(
	scene: PackedScene
) -> void:

	var orbital := scene.instantiate()


	call_deferred(
		"add_child",
		orbital
	)


	orbitals.append(
		orbital
	)


	call_deferred(
		"_recalculate_orbital_spacing"
	)


func _recalculate_orbital_spacing() -> void:

	var count := orbitals.size()


	for i in count:

		orbitals[i].angle_offset = (
			TAU
			* float(i)
			/ float(count)
		)


# ============================================================
# PLAYER SCALE
# ============================================================

func set_player_scale(
	value: float
) -> void:

	player_scale = clamp(
		value,
		PLAYER_SIZE_MIN,
		PLAYER_SIZE_MAX
	)


	anim_sprite.scale = (
		Vector2.ONE
		* player_scale
	)


	body_collision.scale = (
		Vector2.ONE
		* player_scale
	)


	hurtbox_collision.scale = (
		Vector2.ONE
		* player_scale
	)


# ============================================================
# SHOT STYLE
# ============================================================

func equip_shot_style(
	style: ShotStyleModifier
) -> void:

	shot_style = style.duplicate()

	resync_shot_style()


func resync_shot_style() -> void:

	if shot_style:

		shot_style.apply_player_stats(
			self
		)


# ============================================================
# POSITION HISTORY
# ============================================================

func _record_position_history() -> void:

	var now: float = (
		Time.get_ticks_msec()
		/ 1000.0
	)


	position_history.append(
		{
			"time": now,
			"pos": global_position
		}
	)


	while (
		position_history.size() > 0
		and now - position_history[0].time
		> MAX_HISTORY_AGE
	):

		position_history.pop_front()


# ============================================================
# GET TRAILING POSITION
# ============================================================

func get_trailing_position(
	delay: float,
	fallback: Vector2
) -> Vector2:

	if position_history.is_empty():

		return fallback


	var target_time: float = (
		Time.get_ticks_msec()
		/ 1000.0
		- delay
	)


	if (
		target_time
		<= position_history[0].time
	):

		return position_history[0].pos


	for i in range(
		position_history.size() - 1
	):

		var a: Dictionary = (
			position_history[i]
		)

		var b: Dictionary = (
			position_history[i + 1]
		)


		if (
			a.time <= target_time
			and target_time <= b.time
		):

			var t: float = (
				(target_time - a.time)
				/
				max(
					b.time - a.time,
					0.0001
				)
			)


			return a.pos.lerp(
				b.pos,
				t
			)


	return position_history[-1].pos


# ============================================================
# FOLLOWERS
# ============================================================

func add_follower(
	scene: PackedScene,
	trail_delay: float
) -> void:

	var follower := scene.instantiate()


	get_parent().add_child(
		follower
	)


	follower.setup(
		self,
		trail_delay
	)


	followers.append(
		follower
	)


# ============================================================
# SHADOW
# ============================================================

func _spawn_shadow() -> void:

	var shadow: Shadow = (
		SHADOW_SCENE.instantiate()
	)


	var ground_layer := (
		get_tree().get_first_node_in_group(
			"ground_effects"
		)
	)


	var target_parent: Node = (
		ground_layer
		if ground_layer
		else get_parent()
	)


	target_parent.add_child(
		shadow
	)


	shadow.setup(
		self,
		false
	)


# ============================================================
# CAMERA BOUNDS
# ============================================================

func set_camera_bounds(
	room_center: Vector2,
	room_size: Vector2
) -> void:

	var half_size: Vector2 = (
		room_size / 2.0
	)


	camera.limit_left = int(
		room_center.x - half_size.x
	)


	camera.limit_right = int(
		room_center.x + half_size.x
	)


	camera.limit_top = int(
		room_center.y - half_size.y
	)


	camera.limit_bottom = int(
		room_center.y + half_size.y
	)


	camera.reset_smoothing()
