extends Area2D
class_name EnemyProjectile

@export var speed: float = 250.0
@export var damage: float = 1.0
@export var lifetime: float = 3.0
@export var knockback_strength: float = 150.0

var velocity: Vector2 = Vector2.ZERO

const SHADOW_SCENE := preload("res://scenes/effects/Shadow.tscn")
@export var shadow_scale: float = 0.2
@export var shadow_offset: Vector2 = Vector2(0, 2)

func _ready() -> void:
	monitoring = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	_spawn_shadow()
	await get_tree().physics_frame
	monitoring = true
	add_to_group("projectiles")


func launch(dir: Vector2, _shooter_velocity: Vector2 = Vector2.ZERO) -> void:
	velocity = dir.normalized() * speed


func _physics_process(delta: float) -> void:
	global_position += velocity * delta


func _on_body_entered(body: Node) -> void:
	_try_deal_damage(body)


func _on_area_entered(area: Node) -> void:
	var target := area.get_parent()
	if target:
		_try_deal_damage(target)


func _try_deal_damage(target: Node) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage, velocity.normalized(), knockback_strength)
		queue_free()
	elif target.is_in_group("walls"):
		queue_free()


func _spawn_shadow() -> void:
	var shadow := SHADOW_SCENE.instantiate()
	var ground_layer := get_tree().get_first_node_in_group("ground_effects")
	var target_parent: Node = ground_layer if ground_layer else get_parent()
	target_parent.add_child(shadow)
	shadow.scale = Vector2.ONE * shadow_scale
	shadow.offset = shadow_offset
	shadow.setup(self, true)
