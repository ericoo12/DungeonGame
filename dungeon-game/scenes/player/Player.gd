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
const PLAYER_SIZE_MIN := 0.001
const PLAYER_SIZE_MAX := 2.0
@onready var lower_sprite: AnimatedSprite2D = $LowerBodySprite
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
const SHOOT_POSE_DURATION := 0.33  # how long he keeps facing the shot direction after firing
const PROJECTILE_SCENE := preload("res://scenes/player/Projectile.tscn")

# --- Charge shot (set by items with a ChargeShotSettings) ---
var charge_shot: ChargeShotSettings = null
var charge_held: float = 0.0
var charge_aim: Vector2 = Vector2.DOWN
var charge_damage_mult: float = 1.0
var charge_size_mult: float = 1.0
var charge_knockback_mult: float = 1.0
var charge_speed_mult: float = 1.0
const CHARGE_GLOW_COLOR := Color(1.6, 1.3, 0.6)
var charge_projectile_scene: PackedScene = null

# --- Projectile modifiers ---
@export var projectile_range: float = 1.0
const RANGE_MIN := 0.3
const RANGE_MAX := 4.0

@export var projectile_size: float = 1.0
const PROJECTILE_SIZE_MIN := 0.3
const PROJECTILE_SIZE_MAX := 3.0

@export var projectile_knockback: float = 100.0
const KNOCKBACK_MIN := 0.0
const KNOCKBACK_MAX := 500.0

@export var shot_speed: float = 1.0
const SHOT_SPEED_MIN := 0.3
const SHOT_SPEED_MAX := 3.0

# --- Damage ---
@export var base_damage: float = 3.5
var damage_ups: int = 0
var damage_multiplier: float = 1.0

# --- Weapon composition ---
var shot_style: ShotStyleModifier = null
var shot_pattern_modifiers: Array[ShotPatternModifier] = []

#--- Luck ---
var luck: float = 0.0
## Chance-per-shot effects (slow shot, ...). Stack freely; each rolls once per shot.
var shot_procs: Array[ShotProcEffect] = []

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

# --- Lower body ---
const LOWER_ANIM_TRANSFORM := {
	"idle_down": {"scale": 0.75, "offset": Vector2.ZERO},
	"run_down":  {"scale": 0.75, "offset": Vector2.ZERO},
	
	"idle_left": {"scale": 0.75, "offset": Vector2.ZERO},
	"run_left":  {"scale": 0.75, "offset": Vector2(5.0, 0.0)},
	
	"idle_right": {"scale": 0.75, "offset": Vector2.ZERO},
	"run_right":  {"scale": 0.75, "offset": Vector2(-5.0, 0.0)},
	
	"idle_up":   {"scale": 0.75, "offset": Vector2.ZERO},
	"run_up":    {"scale": 0.75, "offset": Vector2(0.0, 0.0)},  # run_up's legs extend ~27px higher than idle_up — shift down to compensate
}

var lower_base_position: Vector2 = Vector2.ZERO  # set once in _ready()

const BODY_TEXTURE_SCALE := 256.0 / 1254.0
const BODY_Z_INDEX := 1  # draws above the lower body (z 0)

# Shoulder-joint pivot of each arm texture, in arm-texture pixels. Puts the shoulder
# on the arm node's origin so position = where the shoulder is and the recoil rotates
# around it. Measured from the art — only change this if the arm art changes.
# Right uses left with X negated (flip_h doesn't mirror Sprite2D.offset by itself).
const ARM_PIVOT := {
	"down": Vector2(9, 116),
	"left": Vector2(-246, -8),
	"up":   Vector2(-13, -143),
}

# Arm reaction when shooting
const ARM_KICK_DISTANCE := 6.0        # head-pixels, pushed opposite the aim direction
const ARM_KICK_ROTATION := 0.25       # radians of muzzle rise, side views only
const ARM_KICK_RETURN_TIME := 0.15
const ARM_FLASH_COLOR := Color(1.8, 1.8, 1.8)

## Where the whole upper body sits relative to the player root, in head-pixels.
@export var body_offset: Vector2 = Vector2(0, 0)

@export_group("Body Pose: Down", "down_")
@export var down_torso_pos: Vector2 = Vector2(0, 5)
@export_range(0.1, 3.0, 0.01) var down_torso_scale: float = 0.75
@export var down_head_pos: Vector2 = Vector2(0, 0)
@export_range(0.1, 3.0, 0.01) var down_head_scale: float = 1.0
@export var down_arm_pos: Vector2 = Vector2(-40, -4)
@export_range(0.1, 3.0, 0.01) var down_arm_scale: float = 0.9
@export var down_arm_behind: bool = false
@export_range(0.0, 1.0, 0.01) var down_arm_shade: float = 1.0
@export var down_offarm_pos: Vector2 = Vector2(36, -10)
@export_range(0.1, 3.0, 0.01) var down_offarm_scale: float = 0.9
@export var down_offarm_behind: bool = false
@export_range(0.0, 1.0, 0.01) var down_offarm_shade: float = 1.0

@export_group("Body Pose: Left", "left_")
@export var left_torso_pos: Vector2 = Vector2(5.0, 8.0)
@export_range(0.1, 3.0, 0.01) var left_torso_scale: float = 0.5
@export var left_head_pos: Vector2 = Vector2(0, 0)
@export_range(0.1, 3.0, 0.01) var left_head_scale: float = 1.0
@export var left_arm_pos: Vector2 = Vector2(10, 6)
@export_range(0.1, 3.0, 0.01) var left_arm_scale: float = 0.75
@export var left_arm_behind: bool = true
@export_range(0.0, 1.0, 0.01) var left_arm_shade: float = 0.8
@export var left_offarm_pos: Vector2 = Vector2(8, -4)
@export_range(0.1, 3.0, 0.01) var left_offarm_scale: float = 0.8
@export var left_offarm_behind: bool = false
@export_range(0.0, 1.0, 0.01) var left_offarm_shade: float = 1.0

@export_group("Body Pose: Right", "right_")
@export var right_torso_pos: Vector2 = Vector2(-5.0, 8.0)
@export_range(0.1, 3.0, 0.01) var right_torso_scale: float = 0.5
@export var right_head_pos: Vector2 = Vector2(0, 0)
@export_range(0.1, 3.0, 0.01) var right_head_scale: float = 1.0
@export var right_arm_pos: Vector2 = Vector2(-10, 6)
@export_range(0.1, 3.0, 0.01) var right_arm_scale: float = 0.75
@export var right_arm_behind: bool = false
@export_range(0.0, 1.0, 0.01) var right_arm_shade: float = 1.0
@export var right_offarm_pos: Vector2 = Vector2(-8, -4)
@export_range(0.1, 3.0, 0.01) var right_offarm_scale: float = 0.75
@export var right_offarm_behind: bool = true
@export_range(0.0, 1.0, 0.01) var right_offarm_shade: float = 0.8

@export_group("Body Pose: Up", "up_")
@export var up_torso_pos: Vector2 = Vector2(0, 10)
@export_range(0.1, 3.0, 0.01) var up_torso_scale: float = 0.75
@export var up_head_pos: Vector2 = Vector2(0, 0)
@export_range(0.1, 3.0, 0.01) var up_head_scale: float = 1.0
@export var up_arm_pos: Vector2 = Vector2(40, -4)
@export_range(0.1, 3.0, 0.01) var up_arm_scale: float = 0.9
@export var up_arm_behind: bool = true
@export_range(0.0, 1.0, 0.01) var up_arm_shade: float = 1.0
@export var up_offarm_pos: Vector2 = Vector2(-36, -10)
@export_range(0.1, 3.0, 0.01) var up_offarm_scale: float = 0.9
@export var up_offarm_behind: bool = false
@export_range(0.0, 1.0, 0.01) var up_offarm_shade: float = 1.0

@export_group("")

@export var down_offarm_visible: bool = true
@export var left_offarm_visible: bool = true
@export var right_offarm_visible: bool = false
@export var up_offarm_visible: bool = true
var body_root: Node2D
var torso_sprite: Sprite2D
var head_sprite: Sprite2D
var arm_sprite: Sprite2D      # gun arm (his right)
var offarm_sprite: Sprite2D   # empty-hand arm (his left)
var body_textures: Dictionary = {}
var arm_kick: Vector2 = Vector2.ZERO   # tweened back to zero after each shot
var arm_kick_rot: float = 0.0
var _arm_tween: Tween

# --- Cosmetics ---
const COSMETIC_SLOTS := ["Head", "Face", "Neck", "Body", "Back", "LeftHand", "RightHand", "Feet", "Aura", "Trail"]
var body_overlays: Array[Node2D] = []   # Body-slot cosmetics, drawn over the torso
# Placeholder positions — tune each by eye per direction, same process as every
# other offset in this file. Values are LEFT-facing canonical positions;
# X is automatically mirrored when facing right.
const SLOT_ANCHOR_OFFSETS := {
	"Head":      {"down": Vector2(0, -45), "left": Vector2(5, -45), "right": Vector2(-5, -45), "up": Vector2(0, -47)},
	"Face":      {"down": Vector2(0, -40), "left": Vector2(8, -40), "right": Vector2(-8, -40), "up": Vector2(0, -42)},
	"Neck":      {"down": Vector2(0, -30), "left": Vector2(5, -30), "right": Vector2(-5, -30), "up": Vector2(0, -32)},
	"Body":      {"down": Vector2(0, -15), "left": Vector2(0, -15), "right": Vector2(0, -15), "up": Vector2(0, -15)},
	"Back":      {"down": Vector2(0, -15), "left": Vector2(-8, -15), "right": Vector2(8, -15), "up": Vector2(0, -13)},
	"LeftHand":  {"down": Vector2(-12, -10), "left": Vector2(-10, -10), "right": Vector2(10, -10), "up": Vector2(-12, -10)},
	"RightHand": {"down": Vector2(12, -10), "left": Vector2(10, -10), "right": Vector2(-10, -10), "up": Vector2(12, -10)},
	"Feet":      {"down": Vector2(0, 60), "left": Vector2(0, 50), "right": Vector2(0, 50), "up": Vector2(0, 50)},
	"Aura":      {"down": Vector2(0, -20), "left": Vector2(0, -20), "right": Vector2(0, -20), "up": Vector2(0, -20)},
	"Trail":     {"down": Vector2(0, 0), "left": Vector2(0, 0), "right": Vector2(0, 0), "up": Vector2(0, 0)},
}

var cosmetic_anchors: Dictionary = {}       # slot name -> Node2D anchor
var equipped_cosmetics: Dictionary = {}     # slot name -> Array[Node2D] instances

func _ready() -> void:
	add_to_group("player")
	body_collision_base_position = body_collision.position
	hurtbox_collision_base_position = hurtbox_collision.position
	hurtbox_base_position = hurtbox.position
	set_player_scale(player_scale)
	current_hearts = max_hearts
	EventBus.player_health_changed.emit(current_hearts, max_hearts)

	lower_sprite.sprite_frames = AnimSheetLoader.build_lower_body_frames()
	lower_base_position = lower_sprite.position
	lower_sprite.play("idle_down")

	_build_body()

	_spawn_shadow()
	
	for slot in COSMETIC_SLOTS:
		var anchor := Node2D.new()
		anchor.name = "CosmeticAnchor_" + slot
		add_child(anchor)
		cosmetic_anchors[slot] = anchor
		equipped_cosmetics[slot] = []

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
		if charge_shot:
			charge_aim = normalized_aim
			if shoot_cooldown <= 0.0:
				charge_held = min(charge_held + delta, _full_charge_time())
		elif shoot_cooldown <= 0.0:
			_shoot(normalized_aim, move_vec.length() > 0.0)
	elif charge_shot and charge_held > 0.0:
		_release_charge()
	elif shoot_timer <= 0.0:
		_update_facing(move_vec)

	_update_charge_glow()

	if active_item_cooldown_timer > 0.0:
		active_item_cooldown_timer = max(active_item_cooldown_timer - delta, 0.0)

	if Input.is_action_just_pressed("use_active_item") and active_item and active_item_cooldown_timer <= 0.0:
		shoot_timer = SHOOT_POSE_DURATION
		active_item.effect.activate(self)
		active_item_cooldown_timer = active_item.cooldown

	_update_animation(move_vec)


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


func _update_animation(move_vec: Vector2) -> void:
	var anim_dir := _facing_suffix()
	var flip := (facing == Facing.RIGHT)
	var frame_dir := "left" if flip else anim_dir

	# --- Lower body ---
	lower_sprite.flip_h = flip

	var lower_frame_name: String = ("run_" if move_vec.length() > 0.0 else "idle_") + frame_dir
	lower_sprite.play(lower_frame_name)

	var lower_transform_key: String = ("run_" if move_vec.length() > 0.0 else "idle_") + anim_dir
	var lower_transform: Dictionary = LOWER_ANIM_TRANSFORM.get(lower_transform_key, {"scale": 1.0, "offset": Vector2.ZERO})
	lower_sprite.scale = Vector2.ONE * player_scale * lower_transform.scale
	lower_sprite.position = (lower_base_position + lower_transform.offset) * player_scale

	# --- Upper body ---
	_update_body(anim_dir, flip)
	
	_update_cosmetic_anchors(anim_dir, flip)


# ============================================================
# UPPER BODY functions
# ============================================================

func _build_body() -> void:
	body_textures = AnimSheetLoader.build_body_part_textures()

	# Container keeps the pieces together. It is NOT y-sorted, so child order is
	# draw order: [arms behind..., torso, head, arms in front...] — set in _update_body().
	body_root = Node2D.new()
	body_root.name = "Body"
	body_root.z_index = BODY_Z_INDEX
	add_child(body_root)

	arm_sprite = _make_body_sprite("ArmSprite")
	offarm_sprite = _make_body_sprite("OffArmSprite")
	torso_sprite = _make_body_sprite("TorsoSprite")
	head_sprite = _make_body_sprite("HeadSprite")

	_update_body("down", false)


func _make_body_sprite(node_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	body_root.add_child(sprite)
	return sprite


# Reads one of the exported per-direction pose values, e.g. _pose("left", "arm_pos").
func _pose(dir: String, key: String) -> Variant:
	return get("%s_%s" % [dir, key])


func _update_body(anim_dir: String, flip: bool) -> void:
	var tex_dir := "left" if flip else anim_dir

	body_root.position = body_offset * player_scale
	body_root.scale = Vector2.ONE * player_scale

	torso_sprite.texture = body_textures.torso[tex_dir]
	head_sprite.texture = body_textures.head[tex_dir]
	arm_sprite.texture = body_textures.arm[tex_dir]
	offarm_sprite.texture = body_textures.offarm[tex_dir]

	torso_sprite.flip_h = flip
	head_sprite.flip_h = flip
	arm_sprite.flip_h = flip
	offarm_sprite.flip_h = flip

	# --- Torso / head ---
	torso_sprite.position = _pose(anim_dir, "torso_pos")
	torso_sprite.scale = Vector2.ONE * BODY_TEXTURE_SCALE * _pose(anim_dir, "torso_scale")
	head_sprite.position = _pose(anim_dir, "head_pos")
	head_sprite.scale = Vector2.ONE * _pose(anim_dir, "head_scale")

	# --- Arm ---
	var pivot: Vector2 = ARM_PIVOT[tex_dir]
	if flip:
		pivot.x = -pivot.x
	arm_sprite.offset = pivot
	arm_sprite.position = _pose(anim_dir, "arm_pos") + arm_kick
	arm_sprite.scale = Vector2.ONE * BODY_TEXTURE_SCALE * _pose(anim_dir, "arm_scale")
	arm_sprite.rotation = arm_kick_rot

	# self_modulate for the shade, modulate is left free for the shot flash
	var shade: float = _pose(anim_dir, "arm_shade")
	arm_sprite.self_modulate = Color(shade, shade, shade)

	# --- Off-hand arm ---
	# Its art already has the top of the shoulder at the canvas center, so no pivot
	# offset is needed and it's 256px like the head (no texture scale).
	offarm_sprite.position = _pose(anim_dir, "offarm_pos")
	offarm_sprite.scale = Vector2.ONE * _pose(anim_dir, "offarm_scale")
	var off_shade: float = _pose(anim_dir, "offarm_shade")
	offarm_sprite.self_modulate = Color(off_shade, off_shade, off_shade)
	offarm_sprite.visible = _pose(anim_dir, "offarm_visible")
	# --- Draw order ---
	var order: Array[Node] = []
	if _pose(anim_dir, "arm_behind"): order.append(arm_sprite)
	if _pose(anim_dir, "offarm_behind"): order.append(offarm_sprite)
	order.append(torso_sprite)
	for overlay in body_overlays:
		if is_instance_valid(overlay):
			order.append(overlay)
	order.append(head_sprite)
	if not _pose(anim_dir, "offarm_behind"): order.append(offarm_sprite)
	if not _pose(anim_dir, "arm_behind"): order.append(arm_sprite)
	for i in order.size():
		if order[i].get_index() != i:
			body_root.move_child(order[i], i)


func _play_arm_kick(aim_dir: Vector2) -> void:
	if _arm_tween and _arm_tween.is_valid():
		_arm_tween.kill()

	arm_kick = -aim_dir * ARM_KICK_DISTANCE
	match facing:
		Facing.LEFT: arm_kick_rot = ARM_KICK_ROTATION    # clockwise = muzzle up when pointing left
		Facing.RIGHT: arm_kick_rot = -ARM_KICK_ROTATION
		_: arm_kick_rot = 0.0
	arm_sprite.modulate = ARM_FLASH_COLOR

	_arm_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_arm_tween.tween_property(self, "arm_kick", Vector2.ZERO, ARM_KICK_RETURN_TIME)
	_arm_tween.tween_property(self, "arm_kick_rot", 0.0, ARM_KICK_RETURN_TIME)
	_arm_tween.tween_property(arm_sprite, "modulate", Color.WHITE, ARM_KICK_RETURN_TIME)


func _facing_suffix() -> String:
	match facing:
		Facing.DOWN: return "down"
		Facing.LEFT: return "left"
		Facing.RIGHT: return "right"  # real direction — mirroring is handled separately via flip
		Facing.UP: return "up"
	return "down"


func get_effective_damage() -> float:
	var scaling_input: float = max(0.0, damage_ups * 1.2 + 1.0)
	return max(0.5, base_damage * sqrt(scaling_input)) * damage_multiplier * charge_damage_mult


func _shoot(aim_dir: Vector2, is_moving: bool) -> void:
	shoot_cooldown = fire_rate
	shoot_timer = SHOOT_POSE_DURATION
	fire_single_shot(aim_dir)
	if arm_sprite:
		_play_arm_kick(aim_dir)


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
	var scene: PackedScene = charge_projectile_scene if charge_projectile_scene else PROJECTILE_SCENE
	var projectile := scene.instantiate()
	projectile.damage = get_effective_damage()
	projectile.knockback_strength = projectile_knockback * charge_knockback_mult
	projectile.lifetime = projectile_range
	projectile.speed_multiplier = shot_speed * charge_speed_mult
	projectile.scale = Vector2.ONE * projectile_size * charge_size_mult
	projectile.shooter = self
	projectile.procs = roll_shot_procs()
	for proc in projectile.procs:
		proc.decorate_projectile(projectile)

	get_parent().add_child(projectile)
	projectile.global_position = weapon_marker.global_position + aim_dir * 10

	var shooter_velocity: Vector2 = velocity if apply_momentum else Vector2.ZERO
	projectile.launch(aim_dir, shooter_velocity)


## Rolls every equipped ShotProcEffect once (luck-scaled) and returns the ones that
## triggered for this shot.
func roll_shot_procs() -> Array[ShotProcEffect]:
	var triggered: Array[ShotProcEffect] = []
	for proc in shot_procs:
		if Luck.roll(proc.get_chance()):
			triggered.append(proc)
	return triggered


func heal(amount: int) -> void:
	current_hearts = mini(current_hearts + amount, max_hearts)
	EventBus.player_health_changed.emit(current_hearts, max_hearts)


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


const ENEMY_COLLISION_LAYER := 3  # "enemies" physics layer (value 4)


func _start_invulnerability() -> void:
	invulnerable = true
	# Walk through enemies while invulnerable, so a swarm can't pin you in a corner.
	set_collision_mask_value(ENEMY_COLLISION_LAYER, false)
	var tween := create_tween()
	tween.set_loops(5)
	tween.tween_property(lower_sprite, "modulate:a", 0.3, 0.1)
	tween.parallel().tween_property(body_root, "modulate:a", 0.3, 0.1)
	tween.tween_property(lower_sprite, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(body_root, "modulate:a", 1.0, 0.1)
	await get_tree().create_timer(INVULN_DURATION).timeout
	invulnerable = false
	lower_sprite.modulate.a = 1.0
	body_root.modulate.a = 1.0
	_restore_enemy_collision()


## Turns enemy collision back on, but only once the player isn't standing inside an
## enemy (switching it on mid-overlap would trap or jitter the player). While still
## overlapping you can keep walking out; contact damage applies as normal again.
func _restore_enemy_collision() -> void:
	while _overlaps_enemy_body():
		await get_tree().physics_frame
		if invulnerable or is_dying:
			return  # hit again: that invulnerability window restores it when it ends
	set_collision_mask_value(ENEMY_COLLISION_LAYER, true)


func _overlaps_enemy_body() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body_collision.shape
	query.transform = body_collision.global_transform
	query.collision_mask = 1 << (ENEMY_COLLISION_LAYER - 1)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _die() -> void:
	if is_dying:
		return
	is_dying = true

	set_physics_process(false)
	velocity = Vector2.ZERO

	lower_sprite.stop()
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


## Center of the HurtBox (chest-down) in world space. Enemies aim here instead of the
## player's origin, which sits higher up on the body.
func get_hurtbox_center() -> Vector2:
	return hurtbox_collision.global_position


func set_player_scale(value: float) -> void:
	player_scale = clamp(value, PLAYER_SIZE_MIN, PLAYER_SIZE_MAX)
	lower_sprite.scale = Vector2.ONE * player_scale
	if body_root:
		body_root.scale = Vector2.ONE * player_scale
		body_root.position = body_offset * player_scale
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

func _update_cosmetic_anchors(anim_dir: String, flip: bool) -> void:
	for slot in COSMETIC_SLOTS:
		var per_dir: Dictionary = SLOT_ANCHOR_OFFSETS.get(slot, {})
		var base_offset: Vector2 = per_dir.get(anim_dir, Vector2.ZERO)
		var offset := base_offset
		if flip:
			offset.x = -offset.x

		var anchor: Node2D = cosmetic_anchors[slot]
		anchor.position = offset * player_scale
		anchor.scale = Vector2.ONE * player_scale * (-1.0 if (flip and slot in ["Head", "Face"]) else 1.0)

func add_cosmetic(scene: PackedScene, slot: String) -> void:
	if not cosmetic_anchors.has(slot):
		push_warning("Player: unknown cosmetic slot '%s'" % slot)
		return
	if slot == "Body" and body_root:
		var overlay := scene.instantiate()
		body_root.add_child(overlay)
		body_overlays.append(overlay)
		equipped_cosmetics[slot].append(overlay)
		return

	var instance := scene.instantiate()
	cosmetic_anchors[slot].add_child(instance)

	var count: int = equipped_cosmetics[slot].size()
	instance.position += Vector2(count * 4, count * -3)  # slight stagger so stacked cosmetics stay visible

	equipped_cosmetics[slot].append(instance)


func _full_charge_time() -> float:
	return max(fire_rate * charge_shot.charge_time_multiplier, 0.05)


func get_charge_ratio() -> float:
	if charge_shot == null:
		return 0.0
	return charge_held / _full_charge_time()


func _release_charge() -> void:
	var ratio := get_charge_ratio()
	charge_held = 0.0
	if arm_sprite:
		arm_sprite.modulate = Color.WHITE  # clear the charge glow

	if ratio < charge_shot.min_charge_ratio:
		return  # released too early, nothing fires

	# t goes 0 → 1 across the usable charge range
	var t: float = 1.0
	if charge_shot.min_charge_ratio < 1.0:
		t = inverse_lerp(charge_shot.min_charge_ratio, 1.0, ratio)

	charge_damage_mult = lerpf(charge_shot.min_damage_multiplier, charge_shot.max_damage_multiplier, t)
	charge_size_mult = lerpf(1.0, charge_shot.max_size_multiplier, t)
	charge_knockback_mult = lerpf(1.0, charge_shot.max_knockback_multiplier, t)
	charge_speed_mult = lerpf(1.0, charge_shot.max_speed_multiplier, t)
	charge_projectile_scene = charge_shot.projectile_scene
	_shoot(charge_aim, false)
	charge_projectile_scene = null
	
	charge_damage_mult = 1.0
	charge_size_mult = 1.0
	charge_knockback_mult = 1.0
	charge_speed_mult = 1.0


# Gun arm glows while charging, and pulses when fully charged.
func _update_charge_glow() -> void:
	if arm_sprite == null or charge_held <= 0.0:
		return
	var ratio := get_charge_ratio()
	var color := Color.WHITE.lerp(CHARGE_GLOW_COLOR, ratio)
	if ratio >= 1.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		color = color.lerp(ARM_FLASH_COLOR, pulse * 0.5)
	arm_sprite.modulate = color
