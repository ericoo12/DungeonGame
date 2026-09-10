extends Control
class_name HeartsDisplay

@export var heart_size: int = 16
@export var heart_spacing: int = 4

var max_hearts: int = 3
var current_hearts: int = 3


func _ready() -> void:
	EventBus.player_health_changed.connect(_on_health_changed)


func _on_health_changed(current: int, max_h: int) -> void:
	current_hearts = current
	max_hearts = max_h
	custom_minimum_size = Vector2((heart_size + heart_spacing) * max_hearts, heart_size)
	queue_redraw()


func _draw() -> void:
	for i in max_hearts:
		var x :float = i * (heart_size + heart_spacing)
		_draw_heart(Vector2(x, 0), heart_size, i < current_hearts)


func _draw_heart(pos: Vector2, size: int, filled: bool) -> void:
	var color := Color(0.85, 0.15, 0.2) if filled else Color(0.25, 0.25, 0.25)
	var s := float(size)
	var lobe_radius := s * 0.28
	var left_center := pos + Vector2(s * 0.28, s * 0.32)
	var right_center := pos + Vector2(s * 0.72, s * 0.32)
	
	draw_circle(left_center, lobe_radius, color)
	draw_circle(right_center, lobe_radius, color)
	
	var triangle := PackedVector2Array([
		pos + Vector2(s * 0.02, s * 0.38),
		pos + Vector2(s * 0.98, s * 0.38),
		pos + Vector2(s * 0.5, s * 0.98),
	])
	draw_colored_polygon(triangle, color)
