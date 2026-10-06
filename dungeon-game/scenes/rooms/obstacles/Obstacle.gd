@tool
extends StaticBody2D
class_name ArenaObstacle

const MOVEMENT_LAYER: int = 1 << 7
const PROJECTILE_LAYER: int = 1 << 8
const SIGHT_LAYER: int = 1 << 9

@export var blocks_movement: bool = true:
	set(value):
		blocks_movement = value
		_request_refresh()
@export var blocks_projectiles: bool = true:
	set(value):
		blocks_projectiles = value
		_request_refresh()
@export var blocks_sight: bool = false:
	set(value):
		blocks_sight = value
		_request_refresh()
@export var obstacle_size := Vector2(32, 32):
	set(value):
		obstacle_size = value.max(Vector2.ONE)
		_request_refresh()
@export var placeholder_color := Color(0.15, 0.8, 0.25, 1):
	set(value):
		placeholder_color = value
		_request_refresh()
@export var show_placeholder: bool = true:
	set(value):
		show_placeholder = value
		_request_refresh()

var _refresh_pending: bool = false

func _ready() -> void:
	_refresh()

func _request_refresh() -> void:
	if not is_inside_tree() or _refresh_pending:
		return
	_refresh_pending = true
	call_deferred("_refresh")

func _refresh() -> void:
	_refresh_pending = false
	if not is_inside_tree():
		return
	collision_layer = 0
	if blocks_movement:
		collision_layer |= MOVEMENT_LAYER
	if blocks_projectiles:
		collision_layer |= PROJECTILE_LAYER
	if blocks_sight:
		collision_layer |= SIGHT_LAYER
	collision_mask = 0
	if blocks_projectiles:
		add_to_group("projectile_blockers")
	else:
		remove_from_group("projectile_blockers")
	# Each instance owns its shape, so resizing one never resizes another.
	var shape := RectangleShape2D.new()
	shape.size = obstacle_size
	$CollisionShape2D.shape = shape
	var half_size := obstacle_size * 0.5
	$Square.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y),
		half_size, Vector2(-half_size.x, half_size.y)
	])
	$Square.color = placeholder_color
	$Square.visible = show_placeholder
