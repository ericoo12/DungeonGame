## Gutterjaw's Ambush, seen from above: the sewage ripple where it swims under the floor.
## While `tracking` it swims after the target with a limited turning speed (sharp moves
## can shake it off); then it stops and shows the red bite circle for `warn_time`.
## Lives in the GroundEffects layer; Gutterjaw frees it after the bite.
extends Node2D

var target: Node2D
var speed: float = 115.0
var catch_up_speed: float = 260.0          # when far away
var turn_rate: float = deg_to_rad(160.0)   # radians per second
var bounds: Rect2 = Rect2()                # global, stays inside
var tracking: bool = true
var dir: Vector2 = Vector2.RIGHT
var warn_radius: float = 24.0
var warn_time: float = 0.0                 # > 0 once the warning started
var _warn_t: float = 0.0
var _t: float = 0.0

const WATER := Color(0.12, 0.16, 0.08)
const RIM := Color(0.62, 0.7, 0.5)
const WARN := Color(0.95, 0.15, 0.1)


func _ready() -> void:
	add_to_group("room_effects")


## Where the ripple aims: the target's feet (falls back to its origin).
func _aim() -> Vector2:
	var feet = target.get("body_collision")
	return (feet as Node2D).global_position if feet is Node2D else target.global_position


func _physics_process(delta: float) -> void:
	_t += delta
	if tracking and is_instance_valid(target):
		var to := _aim() - global_position
		if to.length() > 3.0:
			var want := to.angle()
			var cur := dir.angle()
			var diff := wrapf(want - cur, -PI, PI)
			dir = Vector2.from_angle(cur + clampf(diff, -turn_rate * delta, turn_rate * delta))
			# Catches up quickly from far away, swims at `speed` near you, and slows down
			# right underneath so it doesn't orbit.
			var v := clampf(to.length() * 1.6, speed, catch_up_speed)
			v = minf(v, to.length() * 6.0)
			# Slows down while turning hard (no huge loops around you).
			v *= clampf(cos(diff), 0.25, 1.0)
			global_position += dir * v * delta
		if bounds.has_area():
			global_position = global_position.clamp(bounds.position, bounds.end)
	if warn_time > 0.0:
		_warn_t += delta
	queue_redraw()


func start_warning(seconds: float) -> void:
	tracking = false
	warn_time = seconds
	_warn_t = 0.0


func _draw() -> void:
	# Dark shape under the surface + rings spreading out from it.
	draw_set_transform(Vector2.ZERO, dir.angle(), Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 16.0, Color(WATER, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	for i in 3:
		var k := fmod(_t * 1.4 + i / 3.0, 1.0)
		draw_arc(Vector2.ZERO, 8.0 + k * 22.0, 0.0, TAU, 28, Color(RIM, 0.55 * (1.0 - k)), 1.2)
	# Wake behind it while it swims.
	if tracking:
		draw_set_transform(Vector2.ZERO, dir.angle(), Vector2.ONE)
		for s in [-1.0, 1.0]:
			draw_line(Vector2(-6, 0), Vector2(-24, s * 9.0), Color(RIM, 0.35), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if warn_time > 0.0:
		var k := clampf(_warn_t / warn_time, 0.0, 1.0)
		draw_circle(Vector2.ZERO, warn_radius, Color(WARN, 0.12 + 0.25 * k))
		draw_arc(Vector2.ZERO, warn_radius, 0.0, TAU, 40, Color(WARN, 0.6 + 0.4 * k), 1.5)
		draw_circle(Vector2.ZERO, warn_radius * k, Color(WARN, 0.18))
