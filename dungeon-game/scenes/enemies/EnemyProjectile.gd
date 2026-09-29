extends Area2D
class_name EnemyProjectile

## Same flight model as the player's Projectile: flies straight, hovers above its
## shadow, then over the last part of its flight sinks down onto the shadow and
## splashes when it reaches max_range. Also splashes on hitting the player or a wall.

@export var speed: float = 250.0
@export var damage: float = 1.0
@export var max_range: float = 140.0          # px travelled before it lands (lifetime = max_range / speed)
@export var knockback_strength: float = 150.0

# --- Falling arc (px, in world space) ---
@export var flight_height: float = 6.0        # how high the sprite hovers above its shadow
@export var fall_start_ratio: float = 0.7     # fraction of the flight before it starts dropping

# --- Visuals ---
@export var shadow_scale: float = 0.3
@export var splash_scale: float = 0.2
@export var splash_modulate: Color = Color(1.0, 0.45, 0.45)  # tints the (pink) player splash red

const SHADOW_SCENE := preload("res://scenes/effects/Shadow.tscn")
const SPLASH_SCENE := preload("res://scenes/effects/ProjectileSplash.tscn")

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 1.0
var elapsed: float = 0.0
var has_landed: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	monitoring = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	lifetime = max_range / maxf(speed, 1.0)
	_update_height(0.0)
	_spawn_shadow()
	await get_tree().physics_frame
	monitoring = true
	add_to_group("projectiles")


func launch(dir: Vector2, _shooter_velocity: Vector2 = Vector2.ZERO) -> void:
	velocity = dir.normalized() * speed


func _physics_process(delta: float) -> void:
	if has_landed:
		return
	elapsed += delta
	global_position += velocity * delta

	var progress: float = elapsed / lifetime
	var fall_t: float = 0.0
	if progress >= fall_start_ratio:
		fall_t = clampf((progress - fall_start_ratio) / maxf(1.0 - fall_start_ratio, 0.0001), 0.0, 1.0)
	_update_height(fall_t)

	if elapsed >= lifetime:
		_land()


## Root = ground position (where the shadow and collision are). The sprite is lifted
## by flight_height and eased down to the ground as fall_t goes 0 -> 1.
func _update_height(fall_t: float) -> void:
	var height: float = flight_height * (1.0 - fall_t * fall_t)
	sprite.position.y = -height / scale.y  # root is scaled; convert world px to local


func _on_body_entered(body: Node) -> void:
	_try_deal_damage(body)


func _on_area_entered(area: Node) -> void:
	var target := area.get_parent()
	if target:
		_try_deal_damage(target)


func _try_deal_damage(target: Node) -> void:
	if has_landed:
		return
	if target.has_method("take_damage"):
		target.take_damage(damage, velocity.normalized(), knockback_strength)
		_land()
	elif target.is_in_group("walls"):
		_land()


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
	target_parent.add_child(splash)  # plain Node2D (no physics), safe inside a physics callback
	splash.global_position = sprite.global_position
	splash.scale = Vector2.ONE * splash_scale
	splash.modulate = splash_modulate


func _spawn_shadow() -> void:
	var shadow := SHADOW_SCENE.instantiate()
	var ground_layer := get_tree().get_first_node_in_group("ground_effects")
	var target_parent: Node = ground_layer if ground_layer else get_parent()
	target_parent.add_child(shadow)
	shadow.shadow_scale = shadow_scale  # Shadow.setup() applies this as its scale
	shadow.offset = Vector2.ZERO  # shadow sits on the ground point; the sprite hovers above it
	shadow.setup(self, true)
