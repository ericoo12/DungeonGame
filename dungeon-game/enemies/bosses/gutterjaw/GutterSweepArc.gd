## Tail Sweep tell: the part of the floor the tail is about to sweep (a wide arc behind
## and beside Gutterjaw). Freed when the sweep starts.
##   shadow = true  (default) a soft dark shadow that fades in during the windup, as if
##                  the raised tail's shadow lay over the floor - readable, not a UI marker.
##   shadow = false the old red warning arc.
extends Node2D

var radius: float = 64.0
var center_angle: float = 0.0   # direction of the tail (radians)
var half_arc: float = deg_to_rad(110.0)
var duration: float = 0.55
var shadow: bool = true
var _t: float = 0.0

const COL := Color(0.95, 0.2, 0.1)
const SHADOW := Color(0.0, 0.0, 0.0)
const SHADOW_ALPHA := 0.45      # darkest, at the end of the windup
const STEPS := 28


func _ready() -> void:
	add_to_group("room_effects")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _sector(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in STEPS + 1:
		var a := center_angle - half_arc + 2.0 * half_arc * i / STEPS
		pts.append(Vector2.from_angle(a) * r)
	return pts


func _draw() -> void:
	var k := clampf(_t / maxf(duration, 0.01), 0.0, 1.0)
	if shadow:
		# Soft edge: stacked sectors, the outer rings fainter. Darkens with an ease-in so
		# it's faint at first and clear right before the swing.
		var a := SHADOW_ALPHA * (0.25 + 0.75 * k * k)
		var rings := 4
		for i in rings:
			var r := radius * (1.0 - 0.06 * i)
			draw_colored_polygon(_sector(r), Color(SHADOW, a / rings * (1.0 if i > 0 else 0.6)))
		return
	draw_colored_polygon(_sector(radius), Color(COL, 0.08 + 0.18 * k))
	draw_arc(Vector2.ZERO, radius, center_angle - half_arc, center_angle + half_arc, STEPS, Color(COL, 0.35 + 0.45 * k), 1.5)
