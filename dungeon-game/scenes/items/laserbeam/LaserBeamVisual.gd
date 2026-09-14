## Purely cosmetic — the instant laser (LaserShotStyle) resolves damage via
## raycast BEFORE spawning this; it only draws the fading beam line.
extends Node2D
class_name LaserBeamVisual

@onready var line: Line2D = $Line2D

var duration: float = 0.2
var timer: float = 0.0


func setup(start: Vector2, end: Vector2, width: float, vis_duration: float) -> void:
	global_position = start
	var local_end := end - start

	line.width = width
	line.points = PackedVector2Array([Vector2.ZERO, local_end])
	line.texture_mode = Line2D.LINE_TEXTURE_TILE

	duration = vis_duration


func _process(delta: float) -> void:
	timer += delta
	modulate.a = 1.0 - (timer / duration)
	if timer >= duration:
		queue_free()
