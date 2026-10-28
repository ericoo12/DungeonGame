## A wet pile of hair the rolling Great Clog (phase 3) leaves behind. Walking through
## it slows the player down. Gone after `lifetime`.
extends Node2D
class_name ClogHairPile

@export var radius: float = 11.0
@export var lifetime: float = 5.0
@export var slow: float = 0.5
@export var hair_color: Color = Color(0.36, 0.25, 0.16)

var _t: float = 0.0
var _blobs: Array = []


func _ready() -> void:
	add_to_group("room_effects")
	for i in 7:
		_blobs.append([Vector2.RIGHT.rotated(randf() * TAU) * randf() * radius * 0.6, randf_range(3.0, 6.0), randf() * TAU])


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= lifetime:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.has_method("slow_this_frame") and player.global_position.distance_to(global_position) < radius + 3.0:
		player.slow_this_frame(slow)
	if Engine.get_physics_frames() % 4 == 0:
		queue_redraw()


func _draw() -> void:
	var a := clampf((lifetime - _t) / 0.6, 0.0, 1.0) * clampf(_t / 0.15, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(0.15, 0.12, 0.08, 0.35 * a))
	for b in _blobs:
		var c: Vector2 = b[0]
		draw_circle(c, b[1], Color(hair_color, 0.85 * a))
		for k in 3:
			var ang: float = b[2] + k * 2.1
			draw_line(c, c + Vector2.RIGHT.rotated(ang) * (b[1] + 3.0), Color(hair_color.lightened(0.25), 0.8 * a), 1.0)
