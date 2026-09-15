## A flat ground shadow that tracks a target node's X position but stays
## pinned to the ground layer's own draw order (via GroundEffects), so it
## never gets caught up in the target's own Y-sort/Z-index.
extends Node2D
class_name Shadow

@export var offset: Vector2 = Vector2(0, 16)
@export var shadow_scale: float = 0.3

var target: Node2D
var follows_target_lifetime: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func setup(target_node: Node2D, follow_lifetime: bool = false) -> void:
	target = target_node
	follows_target_lifetime = follow_lifetime
	scale = Vector2.ONE * shadow_scale
	_update_position()


func _process(_delta: float) -> void:
	if follows_target_lifetime and not is_instance_valid(target):
		queue_free()
		return
	if is_instance_valid(target):
		_update_position()


func _update_position() -> void:
	global_position = target.global_position + offset
