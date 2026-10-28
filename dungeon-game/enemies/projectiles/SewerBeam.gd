## A column of sewer water that crashes down on one spot (the wizard's SewerBeamAttack).
##   1. Warning: a dark puddle grows on the floor with drips falling into it (warn_time).
##   2. Crash: a water column drops from above and hits everything in `radius`
##      (the player takes `damage`, floor pickups get splashed away).
##   3. Splash ring, then it fades out.
## Placeholder art is drawn in code. To use real art later, set the textures below:
##   puddle_texture - the warning mark on the floor (seen from above, e.g. 64x32)
##   column_frames  - the falling water column, frames side by side (e.g. 4 x 32x160)
##   splash_frames  - the impact splash, frames side by side (e.g. 6 x 96x48)
extends Node2D
class_name SewerBeam

@export var radius: float = 13.0          # px, hit area on the floor
@export var damage: float = 0.5           # hearts
@export var knockback_strength: float = 60.0
@export var warn_time: float = 0.9
@export var fall_time: float = 0.12       # column drop from the top of the screen
@export var linger_time: float = 0.25     # column stays (and still hurts) this long
@export var fade_time: float = 0.3
@export var column_height: float = 140.0
@export var column_width: float = 10.0

@export_group("Art (optional)")
@export var puddle_texture: Texture2D
@export var column_frames: Texture2D
@export var column_frame_count: int = 4
@export var splash_frames: Texture2D
@export var splash_frame_count: int = 6
@export_group("")

const WATER := Color(0.42, 0.55, 0.22)
const WATER_DARK := Color(0.2, 0.28, 0.1)
const FOAM := Color(0.85, 0.9, 0.7)

var _t: float = 0.0
var _phase: int = 0          # 0 warn, 1 falling, 2 linger, 3 fade
var _fall: float = 0.0       # 0..1 how far the column has come down
var _hit_done: bool = false
var _alpha: float = 1.0
var _drips: Array = []       # [x offset, y above floor, speed]


var _column: Node2D  # falling water + drips, drawn over characters (this node is the floor part)


func _ready() -> void:
	add_to_group("room_props")  # Dungeon._load_room() frees these on room change
	_column = Node2D.new()
	_column.z_as_relative = false
	_column.z_index = 5
	_column.draw.connect(_draw_column)
	add_child(_column)
	for i in 3:
		_drips.append([randf_range(-radius * 0.5, radius * 0.5), randf_range(30.0, 90.0), randf_range(90.0, 140.0)])


func _process(delta: float) -> void:
	_t += delta
	match _phase:
		0:
			for d in _drips:
				d[1] -= d[2] * delta
				if d[1] <= 0.0:
					d[1] = randf_range(60.0, 100.0)
			if _t >= warn_time:
				_phase = 1; _t = 0.0
		1:
			_fall = clampf(_t / fall_time, 0.0, 1.0)
			if _fall >= 1.0:
				_phase = 2; _t = 0.0
				_crash()
		2:
			_hurt_player()  # still dangerous while the column stands
			if _t >= linger_time:
				_phase = 3; _t = 0.0
		3:
			_alpha = 1.0 - _t / fade_time
			if _alpha <= 0.0:
				queue_free()
				return
	queue_redraw()
	_column.queue_redraw()


func _crash() -> void:
	_hurt_player()
	for node in get_tree().get_nodes_in_group("physics_pickups"):
		var pickup := node as PhysicsPickup
		if pickup and pickup.global_position.distance_to(global_position) <= radius * 2.0:
			var away := pickup.global_position - global_position
			pickup.knock(away.normalized() * 120.0 if away.length() > 0.5 else Vector2.ZERO, 110.0)


func _hurt_player() -> void:
	if _hit_done:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	# Feet on the floor: the player's body shape is where they stand.
	var feet := player.body_collision.global_position if player.body_collision else player.global_position
	var d := feet - global_position
	d.y *= 2.0  # the hit area is an ellipse on the floor, flatter than tall
	if d.length() <= radius + 4.0:
		_hit_done = true
		player.take_damage(damage, feet - global_position, knockback_strength)


## Floor part (under characters): the warning puddle and the splash ring.
func _draw() -> void:
	var a := _alpha
	if _phase == 0:
		var grow := clampf(_t / (warn_time * 0.6), 0.2, 1.0)
		var pulse := 0.5 + 0.5 * sin(_t * 18.0)
		if puddle_texture:
			var s := puddle_texture.get_size() * grow * (radius * 2.0 / puddle_texture.get_width())
			draw_texture_rect(puddle_texture, Rect2(-s / 2.0, s), false, Color(1, 1, 1, 0.6 + 0.3 * pulse))
		else:
			_ellipse(self, Vector2.ZERO, radius * grow, Color(WATER_DARK, 0.6 + 0.25 * pulse))
			_ellipse_outline(self, Vector2.ZERO, radius, Color(WATER, 0.55 + 0.4 * pulse))
	elif _phase >= 2 and splash_frames == null:
		var ring := _ring()
		_ellipse(self, Vector2.ZERO, ring, Color(WATER, 0.55 * a))
		_ellipse_outline(self, Vector2.ZERO, ring + 2.0, Color(FOAM, 0.7 * a))


## Air part (over characters): drips, the falling column, splash droplets.
func _draw_column() -> void:
	var c := _column
	var a := _alpha
	if _phase == 0:
		for d in _drips:
			c.draw_line(Vector2(d[0], -d[1]), Vector2(d[0], -d[1] + 4.0), Color(WATER, 0.9), 1.5)
		return
	var top := -column_height
	var bottom := lerpf(top, 0.0, _fall)
	if column_frames:
		var fw := column_frames.get_width() / column_frame_count
		var frame := int(_t * 14.0) % column_frame_count
		c.draw_texture_rect_region(column_frames, Rect2(-column_width / 2.0, top, column_width, bottom - top),
			Rect2(frame * fw, 0, fw, column_frames.get_height()), Color(1, 1, 1, a))
	else:
		var w := column_width * (1.0 if _phase < 3 else 1.0 - _t / fade_time * 0.6)
		c.draw_rect(Rect2(-w / 2.0, top, w, bottom - top), Color(WATER, 0.85 * a))
		c.draw_rect(Rect2(-w / 2.0 + 1.5, top, 2.0, bottom - top), Color(FOAM, 0.6 * a))
		c.draw_rect(Rect2(w / 2.0 - 2.5, top, 1.5, bottom - top), Color(WATER_DARK, 0.6 * a))
	if _phase < 2:
		return
	var k := _t / (linger_time if _phase == 2 else fade_time)
	if splash_frames:
		var sw := splash_frames.get_width() / splash_frame_count
		var sf := clampi(int(k * splash_frame_count), 0, splash_frame_count - 1)
		var size := Vector2(radius * 4.0, radius * 2.0)
		c.draw_texture_rect_region(splash_frames, Rect2(Vector2(-size.x / 2.0, -size.y), size),
			Rect2(sf * sw, 0, sw, splash_frames.get_height()), Color(1, 1, 1, a))
	else:
		var ring := _ring()
		for i in 6:
			var ang := TAU * i / 6.0 + 0.4
			var p := Vector2(cos(ang) * ring * 1.2, sin(ang) * ring * 0.6 - 4.0 - 6.0 * k)
			c.draw_circle(p, 1.5, Color(FOAM, 0.8 * a))


func _ring() -> float:
	var k := _t / (linger_time if _phase == 2 else fade_time)
	return radius * (0.8 + (0.5 * k if _phase == 2 else 0.5 + 0.4 * k))


static func _ellipse(on: CanvasItem, center: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var ang := TAU * i / 20.0
		pts.append(center + Vector2(cos(ang) * r, sin(ang) * r * 0.5))
	on.draw_colored_polygon(pts, color)


static func _ellipse_outline(on: CanvasItem, center: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 21:
		var ang := TAU * i / 20.0
		pts.append(center + Vector2(cos(ang) * r, sin(ang) * r * 0.5))
	on.draw_polyline(pts, color, 1.0)
