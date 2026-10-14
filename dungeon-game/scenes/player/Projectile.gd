extends Area2D
class_name Projectile

@export var base_speed: float = 120.0
@export var momentum_influence: float = 0.55
@export var damage: float = 1.0
@export var lifetime: float = 1.0
@export var knockback_strength: float = 50.0
@export var rise_duration: float = 0.08
@export var speed_multiplier: float = 1.0

var direction: Vector2 = Vector2.RIGHT

const PROJECTILE_SHADOW_BASE_SCALE := 0.2
const PROJECTILE_SHADOW_OFFSET := Vector2(0, 8)  # used when fall_depth isn't set

# --- Falling arc: flies at gun height, then over the final (1 - fall_start_ratio) of its
# lifetime it falls (accelerating, like gravity) by fall_depth and lands on the ground
# line where its shadow is. The WHOLE projectile falls, collision included, so a shot
# that's about to land can still hit an enemy low down, e.g. one hugging the south wall.
# Player sets fall_depth = gun height above the feet; sink_depth is the minimum. ---
@export var flight_height: float = 1.0
@export var sink_depth: float = 6.0
@export var fall_start_ratio: float = 0.7
var fall_depth: float = 0.0
var _fallen: float = 0.0
var _shadow: Shadow


# --- Visuals (override these in inherited scenes like ChargedProjectile.tscn) ---
@export_file("*.png") var sprite_sheet_path: String = "res://assets/sprites/player/projectiles/projectile.png"
@export var sprite_frame_count: int = 4
@export var sprite_fps: float = 10.0


var velocity: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var has_landed: bool = false

## Set by Player._fire_projectile(): who fired it, and which ShotProcEffects
## triggered for this shot (applied to whatever it hits).
var shooter: Player = null
var procs: Array[ShotProcEffect] = []

const SHADOW_SCENE := preload("res://scenes/effects/Shadow.tscn")
const SPLASH_SCENE := preload("res://scenes/effects/ProjectileSplash.tscn")
const PROJECTILE_SPLASH_BASE_SCALE := 0.3

@onready var sprite: AnimatedSprite2D = $HoverPivot/SpriteRotator/AnimatedSprite2D
@onready var hover_pivot: Node2D = $HoverPivot
@onready var sprite_rotator: Node2D = $HoverPivot/SpriteRotator

func _ready() -> void:
	monitoring = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	sprite.sprite_frames = AnimSheetLoader.build_single_animation(
		sprite_sheet_path, sprite_frame_count, sprite_fps, true
	)
	sprite.play("splash")
	_spawn_shadow()
	await get_tree().physics_frame
	monitoring = true
	add_to_group("projectiles")

func launch(aim_dir: Vector2, shooter_velocity: Vector2) -> void:
	var parallel_speed: float = shooter_velocity.dot(aim_dir)
	var parallel_component: Vector2 = aim_dir * max(parallel_speed, 0.0)
	var perpendicular_component: Vector2 = shooter_velocity - aim_dir * parallel_speed
	var momentum: Vector2 = (parallel_component + perpendicular_component) * momentum_influence
	velocity = aim_dir * base_speed * speed_multiplier + momentum
	sprite_rotator.rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	if has_landed:
		return

	elapsed += delta
	global_position += velocity * delta

	var progress: float = elapsed / lifetime
	var depth: float = maxf(fall_depth, sink_depth)

	if progress >= fall_start_ratio:
		var fall_t: float = clampf((progress - fall_start_ratio) / max(1.0 - fall_start_ratio, 0.0001), 0.0, 1.0)
		var target_fall: float = depth * fall_t * fall_t  # accelerating drop
		global_position.y += target_fall - _fallen       # moves the collision down too
		_fallen = target_fall

	# Shadow stays on the ground line while the projectile drops towards it.
	if _shadow and fall_depth > 0.0:
		_shadow.offset = Vector2(0, depth - _fallen)

	if elapsed >= lifetime:
		_land()


func _spawn_shadow() -> void:
	var shadow: Shadow = SHADOW_SCENE.instantiate()
	_shadow = shadow
	var ground_layer := get_tree().get_first_node_in_group("ground_effects")
	var target_parent: Node = ground_layer if ground_layer else get_parent()
	target_parent.add_child(shadow)
	shadow.shadow_scale = PROJECTILE_SHADOW_BASE_SCALE * scale.x
	shadow.offset = PROJECTILE_SHADOW_OFFSET
	shadow.setup(self, true)


func _land() -> void:
	if has_landed:
		return
	has_landed = true
	_spawn_splash()
	queue_free()


func _spawn_splash() -> void:
	var splash: ProjectileSplash = SPLASH_SCENE.instantiate()
	var ground_layer := get_tree().get_first_node_in_group("ground_effects")
	var target_parent: Node = ground_layer if ground_layer else get_parent()
	target_parent.add_child(splash)
	splash.global_position = global_position + hover_pivot.position
	splash.scale = Vector2.ONE * (PROJECTILE_SPLASH_BASE_SCALE * scale.x)


func _on_body_entered(body: Node) -> void:
	_try_deal_damage(body)


func _on_area_entered(area: Node) -> void:
	_try_deal_damage(area)


func _try_deal_damage(target: Node) -> void:
	if has_landed:
		return
	if target.has_method("take_damage"):
		target.take_damage(damage, velocity.normalized(), knockback_strength)
		for proc in procs:
			proc.on_hit(target, shooter)
		_land()
	elif target.is_in_group("walls") or target.is_in_group("projectile_blockers"):  # final-arena blue blocks
		_land()
