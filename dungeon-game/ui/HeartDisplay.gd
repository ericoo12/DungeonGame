extends Control
class_name HeartsDisplay

@export var heart_size: int = 16
@export var heart_spacing: int = 4

var max_hearts: int = 3
var current_hearts: float = 3


func _ready() -> void:
	EventBus.player_health_changed.connect(_on_health_changed)


func _on_health_changed(current: float, max_h: int) -> void:
	current_hearts = current
	max_hearts = max_h
	custom_minimum_size = Vector2((heart_size + heart_spacing) * max_hearts, heart_size)
	queue_redraw()


func _draw() -> void:
	for i in max_hearts:
		var x :float = i * (heart_size + heart_spacing)
		_draw_heart(Vector2(x, 0), heart_size, clampf(current_hearts - i, 0.0, 1.0))


func _draw_heart(pos: Vector2, size: int, fill: float) -> void:
	var outline := PackedVector2Array([
		Vector2(0.5, 0.2), Vector2(0.3, 0.04), Vector2(0.12, 0.04),
		Vector2(0.0, 0.2), Vector2(0.0, 0.42), Vector2(0.5, 0.98),
		Vector2(1.0, 0.42), Vector2(1.0, 0.2), Vector2(0.88, 0.04), Vector2(0.7, 0.04)
	])
	for i in outline.size():
		outline[i] = pos + outline[i] * size
	draw_colored_polygon(outline, Color(0.25, 0.25, 0.25))
	if fill <= 0.0:
		return
	var clip := PackedVector2Array([pos, pos + Vector2(size * fill, 0), pos + Vector2(size * fill, size), pos + Vector2(0, size)])
	for polygon in Geometry2D.intersect_polygons(outline, clip):
		draw_colored_polygon(polygon, Color(0.85, 0.15, 0.2))
