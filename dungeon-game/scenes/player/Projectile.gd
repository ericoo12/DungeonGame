extends Area2D
class_name Projectile

@export var base_speed: float = 120.0
@export var momentum_influence: float = 0.55
@export var damage: float = 1.0
@export var lifetime: float = 1.0
@export var knockback_strength: float = 50.0
@export var rise_duration: float = 0.08

var direction: Vector2 = Vector2.RIGHT

const PROJECTILE_SHADOW_BASE_SCALE := 0.2
const PROJECTILE_SHADOW_OFFSET := Vector2(0, 8)

# --- Falling arc: hovers at flight_height during flight, then descends to 0
# over the final (1 - fall_start_ratio) portion of its lifetime, landing
# exactly where its own shadow already is. ---
@export var flight_height: float = 1.0
@export var sink_depth: float = 6.0
@export var fall_start_ratio: float = 0.75

var velocity: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var has_landed: bool = false

const SHADOW_SCENE := preload("res://scenes/effects/Shadow.tscn")
const SPLASH_SCENE := preload("res://scenes/effects/ProjectileSplash.tscn")
const PROJECTILE_SPLASH_BASE_SCALE := 0.3

@onready var hover_pivot: Node2D = $HoverPivot
@onready var sprite_rotator: Node2D = $HoverPivot/SpriteRotator

func _ready() -> void:
	monitoring = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_spawn_shadow()
	await get_tree().physics_frame
	monitoring = true


func launch(aim_dir: Vector2, shooter_velocity: Vector2) -> void:
	var parallel_speed: float = shooter_velocity.dot(aim_dir)
	var parallel_component: Vector2 = aim_dir * max(parallel_speed, 0.0)
	var perpendicular_component: Vector2 = shooter_velocity - aim_dir * parallel_speed
	var momentum: Vector2 = (parallel_component + perpendicular_component) * momentum_influence
	velocity = aim_dir * base_speed + momentum
	sprite_rotator.rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	if has_landed:
		return

	elapsed += delta
	global_position += velocity * delta

	var progress: float = elapsed / lifetime
	var y_offset: float = 0.0

	if progress >= fall_start_ratio:
		var fall_t: float = (progress - fall_start_ratio) / max(1.0 - fall_start_ratio, 0.0001)
		y_offset = lerp(0.0, sink_depth, clamp(fall_t, 0.0, 1.0))

	hover_pivot.position.y = y_offset

	if elapsed >= lifetime:
		_land()


func _spawn_shadow() -> void:
	var shadow: Shadow = SHADOW_SCENE.instantiate()
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
		_land()
	elif target.is_in_group("walls"):
		_land()
