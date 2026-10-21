extends Area2D
class_name StageDoor

const DOOR_PATH := "res://assets/sprites/objects//toilet.png"  # replace with wherever your actual file lives

var activated: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.sprite_frames = AnimSheetLoader.build_single_animation_indexed(DOOR_PATH, [2, 3], 4, 4.0, true, "open")
	visible = false
	monitoring = false
	body_entered.connect(_on_body_entered)


func activate() -> void:
	if activated:
		return
	activated = true
	visible = true
	sprite.play("open")
	monitoring = true


func _on_body_entered(body: Node) -> void:
	if not activated or not body.is_in_group("player"):
		return
	var dungeon := get_tree().get_first_node_in_group("dungeon")
	if dungeon:
		dungeon.call_deferred("advance_to_next_stage")
