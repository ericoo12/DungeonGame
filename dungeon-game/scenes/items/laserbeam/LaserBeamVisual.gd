## Purely cosmetic — the instant laser (LaserShotStyle) resolves damage via
## raycast BEFORE spawning this; it only draws the fading beam line.
## The beam is a child of the player, so it follows the muzzle while fading.
## Its length is re-raycast every physics frame (visual only, no extra damage),
## so it stops at walls/obstacles/enemies instead of sliding through them.
extends Node2D
class_name LaserBeamVisual

@onready var line: Line2D = $Line2D

var duration: float = 0.2
var timer: float = 0.0

var direction: Vector2 = Vector2.RIGHT
var max_range: float = 3000.0
var collision_mask: int = 0
var exclude: Array[RID] = []


func setup(start: Vector2, end: Vector2, width: float, vis_duration: float,
		dir: Vector2, range_limit: float, mask: int, exclude_rids: Array[RID] = []) -> void:
	global_position = start
	direction = dir.normalized()
	max_range = range_limit
	collision_mask = mask
	exclude = exclude_rids

	line.width = width
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	_set_length(start.distance_to(end))  # same frame as the damage raycast: reuse its result

	duration = vis_duration


func _physics_process(_delta: float) -> void:
	var from := global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + direction * max_range, collision_mask, exclude)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	_set_length(from.distance_to(hit.position) if hit else max_range)


func _process(delta: float) -> void:
	timer += delta
	modulate.a = 1.0 - (timer / duration)
	if timer >= duration:
		queue_free()


func _set_length(length: float) -> void:
	line.points = PackedVector2Array([Vector2.ZERO, direction * length])
