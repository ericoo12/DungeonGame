extends StaticBody2D
class_name TestDummy

@export var max_health: float = 10000
var health: float

## Contact damage, same as enemies (EnemyBase): hurts the player's HurtBox on touch and
## again every contact_damage_interval while they stay on it. 0 = harmless.
@export var contact_damage: int = 1
@export var contact_damage_interval: float = 0.6
@export var contact_knockback_strength: float = 100.0

var _touching: Array[Area2D] = []
var _contact_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	health = max_health
	_update_label()
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hitbox.area_exited.connect(func(area: Area2D): _touching.erase(area))


func _physics_process(delta: float) -> void:
	if _touching.is_empty() or contact_damage <= 0:
		return
	_contact_timer -= delta
	if _contact_timer <= 0.0:
		_contact_timer = contact_damage_interval
		for area in _touching:
			_hurt(area)


func _on_hitbox_area_entered(area: Area2D) -> void:
	if not _touching.has(area):
		_touching.append(area)
	_contact_timer = contact_damage_interval
	_hurt(area)


func _hurt(area: Area2D) -> void:
	if contact_damage <= 0 or not is_instance_valid(area):
		return
	var target := area.get_parent()
	if target and target.has_method("take_damage"):
		target.take_damage(contact_damage, target.global_position - global_position, contact_knockback_strength)

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
