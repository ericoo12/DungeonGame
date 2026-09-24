extends Area2D
class_name Door

@export var direction: Vector2i = Vector2i.ZERO
@export var closed_texture: Texture2D
@export var open_texture: Texture2D
var unlocked: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var physical_blocker: CollisionShape2D = $PhysicalBlocker/CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_unlocked(unlocked) 
	_update_visual()

func set_unlocked(value: bool) -> void:
	unlocked = value
	monitoring = value
	physical_blocker.set_deferred("disabled", value)
	_update_visual()


func _update_visual() -> void:
	sprite.texture = open_texture if unlocked else closed_texture


func _on_body_entered(body: Node) -> void:
	if not unlocked or not body.is_in_group("player"):
		return
	var dungeon := get_tree().get_first_node_in_group("dungeon")
	if dungeon:
		dungeon.call_deferred("travel", direction)
