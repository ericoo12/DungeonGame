## Red mark on the floor where a Challenge Room enemy is about to appear. Emits
## `finished` after `duration` and frees itself; the room spawns the enemy then.
extends Node2D
class_name SpawnWarning

signal finished

@export var duration: float = 0.8
@export var radius: float = 9.0

var _t: float = 0.0


func _ready() -> void:
	add_to_group("room_effects")  # Dungeon._load_room() clears these


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		finished.emit()
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / duration
	var pulse := 0.5 + 0.5 * sin(_t * 20.0)
	var r := radius * (0.4 + 0.6 * k)
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.5))
	draw_colored_polygon(pts, Color(0.75, 0.05, 0.05, 0.25 + 0.25 * pulse))
	pts.append(pts[0])
	draw_polyline(pts, Color(1.0, 0.25, 0.2, 0.6 + 0.4 * pulse), 1.0)
