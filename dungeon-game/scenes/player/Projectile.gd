extends Area2D
class_name Projectile

@export var base_speed: float = 120.0
@export var momentum_influence: float = 0.55
@export var damage: float = 1.0
@export var lifetime: float = 1.0
@export var knockback_strength: float = 100.0

var direction: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO

func launch(aim_dir: Vector2, shooter_velocity: Vector2) -> void:
	var parallel_speed: float = shooter_velocity.dot(aim_dir)
	var parallel_component: Vector2 = aim_dir * max(parallel_speed, 0.0)
	var perpendicular_component: Vector2 = shooter_velocity - aim_dir * parallel_speed
	var momentum: Vector2 = (parallel_component + perpendicular_component) * momentum_influence

	velocity = aim_dir * base_speed + momentum
	rotation = velocity.angle()

func _ready() -> void:
	monitoring = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	await get_tree().physics_frame
	monitoring = true

func _physics_process(delta: float) -> void:
	global_position += velocity * delta


func _on_body_entered(body: Node) -> void:
	_try_deal_damage(body)


func _on_area_entered(area: Node) -> void:
	_try_deal_damage(area)


func _try_deal_damage(target: Node) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage, velocity.normalized(), knockback_strength)
		queue_free()
	elif target.is_in_group("walls"):
		queue_free()
