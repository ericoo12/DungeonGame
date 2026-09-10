extends StaticBody2D
class_name TestDummy

@export var max_health: float = 10000
var health: float

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready() -> void:
	health = max_health
	_update_label()

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, knockback_strength: float = 0.0) -> void:
	health -= amount
	_update_label()
	_flash()
	if health <= 0:
		queue_free()

func _flash() -> void:
	sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(sprite):
		sprite.modulate = Color(1, 1, 1)

func _update_label() -> void:
	label.text = str(health)
