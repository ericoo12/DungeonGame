## A Great Clog hair tentacle. Three kinds:
##   THRUST - out of a doorway: a red lane shows where it will go (the tip already pokes
##            out of the door), then the arm shoots straight across, holds, retracts.
##   SWIPE  - from the boss's mouth: a red sector shows where it will sweep (telegraph),
##            then a long hair arm sweeps across that arc and retracts. (Unused now.)
##   BURST - from a floor grate (phase 2): a red circle on the grate, then a hair
##           column bursts up and lashes around for a moment.
## Hurts the player once per tentacle. Drawn in code (hair strands) - no art needed,
## but the colours are exports so they can match the boss sprite.
extends Node2D
class_name ClogTentacle

signal finished

enum Kind { SWIPE, BURST, THRUST }

@export var hair_color: Color = Color(0.36, 0.25, 0.16)
@export var hair_light: Color = Color(0.58, 0.45, 0.3)
@export var warn_color: Color = Color(1.0, 0.25, 0.2)
## Door tentacles warn with a shadow on the floor instead of red.
@export var shadow_color: Color = Color(0.03, 0.02, 0.02)

var kind: Kind = Kind.SWIPE
var damage: float = 0.5
var telegraph_time: float = 0.75

# SWIPE
var length: float = 160.0
var arc_from: float = 0.0    # angles (radians), sweeps from -> to
var arc_to: float = 1.0
var sweep_time: float = 0.3
var width: float = 14.0
## THRUST: seconds it stays fully out before pulling back.
var hold_time: float = 0.3

# BURST
var radius: float = 16.0
var active_time: float = 0.6

var _t: float = 0.0
var _state: int = 0          # 0 telegraph, 1 strike, 2 retract
var _hit: bool = false
var _angle: float = 0.0
var _extend: float = 0.0     # 0..1


func setup_swipe(origin: Vector2, center_angle: float, half_arc: float, arm_length: float,
		warn_time: float, swipe_time: float, dmg: float) -> void:
	kind = Kind.SWIPE
	global_position = origin
	var flip := 1.0 if randf() < 0.5 else -1.0
	arc_from = center_angle - half_arc * flip
	arc_to = center_angle + half_arc * flip
	length = arm_length
	telegraph_time = warn_time
	sweep_time = swipe_time
	damage = dmg
	_angle = arc_from


func setup_thrust(origin: Vector2, dir: Vector2, arm_length: float, warn_time: float,
		dmg: float) -> void:
	kind = Kind.THRUST
	global_position = origin
	arc_from = dir.angle()
	arc_to = arc_from
	_angle = arc_from
	length = arm_length
	telegraph_time = warn_time
	sweep_time = 0.14
	damage = dmg


func setup_burst(pos: Vector2, warn_time: float, dmg: float) -> void:
	kind = Kind.BURST
	global_position = pos
	telegraph_time = warn_time
	damage = dmg


func _ready() -> void:
	add_to_group("room_effects")  # Dungeon clears these on room change
	z_index = 2


func _physics_process(delta: float) -> void:
	_t += delta
	match _state:
		0:
			if kind == Kind.SWIPE:
				_extend = clampf(_t / telegraph_time, 0.0, 1.0) * 0.25  # arm creeps out
			elif kind == Kind.THRUST:
				_extend = clampf(_t / telegraph_time, 0.0, 1.0) * 0.12  # tip pokes out of the door
			if _t >= telegraph_time:
				_state = 1
				_t = 0.0
		1:
			if kind == Kind.THRUST:
				_extend = minf(1.0, 0.12 + _t / sweep_time)
				_check_hit_swipe()
				if _t >= sweep_time + hold_time:
					_state = 2
					_t = 0.0
			elif kind == Kind.SWIPE:
				var k := clampf(_t / sweep_time, 0.0, 1.0)
				_extend = minf(1.0, 0.25 + k * 3.0)
				_angle = lerp_angle(arc_from, arc_to, k * k * (3.0 - 2.0 * k))
				_check_hit_swipe()
				if _t >= sweep_time:
					_state = 2
					_t = 0.0
			else:
				_extend = minf(1.0, _t / 0.08)
				if _t < active_time * 0.6:
					_check_hit_burst()
				if _t >= active_time:
					_state = 2
					_t = 0.0
		2:
			_extend = maxf(0.0, _extend - delta / 0.25)
			if _extend <= 0.0:
				finished.emit()
				queue_free()
				return
	queue_redraw()


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _player_point(player: Node2D) -> Vector2:
	return player.call("get_hurtbox_center") if player.has_method("get_hurtbox_center") else player.global_position


func _check_hit_swipe() -> void:
	if _hit:
		return
	var player := _player()
	if player == null:
		return
	var p := _player_point(player)
	var a := global_position
	var b := a + Vector2.RIGHT.rotated(_angle) * length * _extend
	var closest := Geometry2D.get_closest_point_to_segment(p, a, b)
	if closest.distance_to(p) < width * 0.5 + 6.0:
		_hurt(player, p - a)


func _check_hit_burst() -> void:
	if _hit:
		return
	var player := _player()
	if player == null:
		return
	var p := _player_point(player)
	if p.distance_to(global_position + Vector2(0, -6)) < radius + 4.0:
		_hurt(player, p - global_position)


func _hurt(player: Node2D, away: Vector2) -> void:
	_hit = true
	if player.has_method("take_damage"):
		player.take_damage(damage, away.normalized(), 160.0)


func _draw() -> void:
	match kind:
		Kind.SWIPE: _draw_swipe()
		Kind.THRUST: _draw_thrust()
		_: _draw_burst()


func _draw_thrust() -> void:
	var dir := Vector2.RIGHT.rotated(_angle)
	if _state == 0:
		# A shadow on the floor where the arm will land: soft edges, darkening as it nears.
		var k := clampf(_t / telegraph_time, 0.0, 1.0)
		var reach := length * (0.35 + 0.65 * minf(1.0, k * 1.6))  # the shadow stretches out
		var end := dir * reach
		for layer in [[width * 0.5 + 4.0, 0.12], [width * 0.5, 0.22]]:
			var side := dir.orthogonal() * float(layer[0])
			var pts := PackedVector2Array([side, end + side, end - side, -side])
			draw_colored_polygon(pts, Color(shadow_color, float(layer[1]) * (0.4 + 0.6 * k)))
		draw_circle(end, width * 0.5 + 2.0, Color(shadow_color, 0.25 * k))
	if _extend > 0.0:
		_draw_arm(dir, length * _extend, width)


func _draw_swipe() -> void:
	if _state == 0:
		# Telegraph: the whole sweep area, pulsing.
		var pulse := 0.18 + 0.12 * sin(_t * 18.0)
		var pts := PackedVector2Array([Vector2.ZERO])
		var steps := 18
		for i in steps + 1:
			pts.append(Vector2.RIGHT.rotated(lerp_angle(arc_from, arc_to, float(i) / steps)) * length)
		draw_colored_polygon(pts, Color(warn_color, pulse))
		draw_polyline(pts, Color(warn_color, 0.6), 1.0)
		# Arrow-ish tick showing the sweep direction at the far end.
		var end_dir := Vector2.RIGHT.rotated(arc_to)
		draw_line(end_dir * (length - 14.0), end_dir * length, Color(warn_color, 0.9), 2.0)
	if _extend <= 0.0:
		return
	_draw_arm(Vector2.RIGHT.rotated(_angle), length * _extend, width)


func _draw_burst() -> void:
	if _state == 0:
		# No red marker: a few hair tips start wriggling up out of the drain instead.
		var k := clampf(_t / telegraph_time, 0.0, 1.0)
		for i in 4:
			var base := Vector2((float(i) - 1.5) * 3.0, 0.0)
			var tip := base + Vector2(sin(_t * 18.0 + i * 1.7) * 2.0, -(2.0 + 6.0 * k))
			draw_line(base, tip, hair_color if i % 2 == 0 else hair_light, 1.5)
		return
	if _extend <= 0.0:
		return
	# A column of hair whipping around, rising out of the grate.
	var h := 30.0 * _extend
	var lean := Vector2(sin(_t * 22.0) * 5.0, -h)
	_draw_arm(lean.normalized(), lean.length(), 10.0)
	draw_circle(Vector2.ZERO, 7.0 * _extend, Color(hair_color.darkened(0.3), 0.9))


## Bunch of wavy strands from the origin along `dir`.
func _draw_arm(dir: Vector2, arm_len: float, arm_width: float) -> void:
	var side := dir.orthogonal()
	var strands := 7
	for s in strands:
		var off := (float(s) - 3.0) / 3.0 * arm_width * 0.5
		var pts := PackedVector2Array()
		var segs := 10
		for i in segs + 1:
			var k := float(i) / segs
			var taper := 1.0 - k * 0.7
			var wave := sin(k * 9.0 + _t * 14.0 + s) * 2.2 * k
			pts.append(dir * arm_len * k + side * (off * taper + wave))
		var col := hair_color if s % 2 == 0 else hair_light
		draw_polyline(pts, col, 3.0 if s == 3 else 2.0)
