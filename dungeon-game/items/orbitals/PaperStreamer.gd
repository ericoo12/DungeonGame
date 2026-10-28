## Toilet Roll: the paper streamer it unrolls behind itself as it spins. Each strip lasts
## `lifetime` seconds; enemies crossing it are slowed. Lives in the GroundEffects layer
## (made by Orbital when paper_trail is on).
extends Node2D
class_name PaperStreamer

@export var lifetime: float = 1.2
@export var width: float = 3.0
@export var slow_factor: float = 0.5
@export var slow_time: float = 0.35
@export var color: Color = Color(0.96, 0.95, 0.9)

var source: Node2D           # the orbital
var _segments: Array = []    # [from, to, age]
var _last: Vector2
var _has_last: bool = false


func _ready() -> void:
	# Not a room effect: it lives as long as the toilet roll does. Strips are just
	# cleared when you enter another room.
	global_position = Vector2.ZERO
	EventBus.room_entered.connect(_clear)


func _clear() -> void:
	_segments.clear()
	_has_last = false


func _physics_process(delta: float) -> void:
	for s in _segments:
		s[2] += delta
	while not _segments.is_empty() and _segments[0][2] >= lifetime:
		_segments.pop_front()
	if is_instance_valid(source) and source.visible and source.is_inside_tree():
		var p := source.global_position + Vector2(0, 4)
		if not _has_last:
			_last = p
			_has_last = true
		elif p.distance_to(_last) >= 3.0:
			if p.distance_to(_last) < 30.0:  # skip jumps (room change, teleport)
				_segments.append([_last, p, 0.0])
			_last = p
	elif not is_instance_valid(source) and _segments.is_empty():
		queue_free()
		return
	_slow_enemies()
	queue_redraw()


func _slow_enemies() -> void:
	if _segments.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	for node in player.get_parent().get_children():
		var e := node as EnemyBase
		if e == null or e.is_dying:
			continue
		for s in _segments:
			if Geometry2D.get_closest_point_to_segment(e.global_position, s[0], s[1]).distance_to(e.global_position) < width + 5.0:
				e.apply_slow(slow_factor, slow_time)
				break


func _draw() -> void:
	for s in _segments:
		var a := 1.0 - float(s[2]) / lifetime
		draw_line(s[0], s[1], Color(color, 0.85 * a), width)
