## Dizzy stars circling over Gutterjaw's head while it's stunned.
extends Node2D

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	for i in 3:
		var a := _t * 5.0 + i * TAU / 3.0
		var p := Vector2(cos(a) * 11.0, sin(a) * 4.0)
		var s := 2.5
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.6, 0), p + Vector2(0, s), p + Vector2(-s * 0.6, 0)]),
			Color(1.0, 0.92, 0.3, 0.9 if sin(a) > -0.2 else 0.5))
