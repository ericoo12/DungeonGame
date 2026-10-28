## The shadow lane the Great Clog (phase 3) shows before it rolls: from the boss to
## where it will crash, as wide as the boss. Darkens as the roll gets closer.
## The boss frees it when the roll starts.
extends Node2D
class_name ClogLaneWarning

var from: Vector2
var to: Vector2
var width: float = 50.0
var duration: float = 0.8
var _t: float = 0.0
const SHADOW := Color(0.03, 0.02, 0.02)


func _ready() -> void:
	add_to_group("room_effects")
	global_position = Vector2.ZERO


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# A shadow on the floor along the path (like the door tentacles): soft edges, it
	# stretches out from the boss and darkens as the roll gets closer.
	var k := clampf(_t / maxf(duration, 0.01), 0.0, 1.0)
	var dir := (to - from).normalized()
	var reach := from.distance_to(to) * (0.3 + 0.7 * minf(1.0, k * 1.5))
	var end := from + dir * reach
	for layer in [[width * 0.5 + 5.0, 0.12], [width * 0.5, 0.22]]:
		var side := dir.orthogonal() * float(layer[0])
		var pts := PackedVector2Array([from + side, end + side, end - side, from - side])
		draw_colored_polygon(pts, Color(SHADOW, float(layer[1]) * (0.4 + 0.6 * k)))
	# Darker blob where it will crash.
	draw_circle(end, width * 0.5, Color(SHADOW, 0.2 * k))
