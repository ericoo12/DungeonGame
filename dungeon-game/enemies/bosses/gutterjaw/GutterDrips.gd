## Tail Sweep tell: sewage drips falling off Gutterjaw's raised tail, faster and faster
## until the swing. Child of Gutterjaw (drawn over it); `tip` is the tail tip (local).
## Each drop falls to the floor and leaves a tiny splash.
extends Node2D

var tip: Vector2 = Vector2.ZERO
var duration: float = 0.7
var ground_y: float = 2.0        # local y where drops land
var _t: float = 0.0
var _next: float = 0.0
var _drops: Array = []           # [pos, vel, landed_time or -1]

const COL := Color(0.5, 0.58, 0.18)
const HI := Color(0.85, 0.9, 0.5)
const GRAVITY := 520.0


func _ready() -> void:
	add_to_group("room_effects")
	z_index = 1


func _process(delta: float) -> void:
	_t += delta
	if _t > duration + 0.6:
		queue_free()
		return
	var k := clampf(_t / maxf(duration, 0.01), 0.0, 1.0)
	_next -= delta
	if _t < duration and _next <= 0.0:
		# Slow drips at first, a stream right before the swing.
		_next = lerpf(0.16, 0.03, k * k)
		var v := Vector2(randf_range(-25.0, 25.0), randf_range(-30.0, 10.0))
		_drops.append([tip + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0)), v, -1.0])
	for d in _drops:
		if d[2] < 0.0:
			d[1].y += GRAVITY * delta
			d[0] += d[1] * delta
			if d[0].y >= ground_y and d[1].y > 0.0:
				d[0].y = ground_y
				d[2] = _t
	_drops = _drops.filter(func(d): return d[2] < 0.0 or _t - d[2] < 0.3)
	queue_redraw()


func _draw() -> void:
	for d in _drops:
		if d[2] < 0.0:
			draw_rect(Rect2(d[0] - Vector2(1.5, 2), Vector2(3, 4)), COL)
			draw_rect(Rect2(d[0] - Vector2(1.5, 2), Vector2(1.5, 1.5)), HI)
		else:
			var s: float = (_t - d[2]) / 0.3
			draw_set_transform(d[0], 0.0, Vector2(1.0, 0.45))
			draw_arc(Vector2.ZERO, 2.0 + s * 5.0, 0.0, TAU, 12, Color(HI, 0.9 * (1.0 - s)), 1.2)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
