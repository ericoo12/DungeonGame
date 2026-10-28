## The Great Clog, phase 2 (Backflow): sewer water floods the floor.
##   - A CURRENT runs sideways across the room (along the drain wall) and flips
##     direction every `flip_time` seconds (it slows to a stop first = the warning).
##   - SUCTION (the boss calls start_suction()): everything is pulled to the drain mouth.
## Both push EVERYTHING in the water, not just the player: enemies (add_external_push),
## every shot in the "projectiles" group (player shots too - they curve with the water)
## and loose rubbish. Lives in the GroundEffects layer (drawn under everything).
extends Node2D
class_name BackflowWater

## Sideways push (px/s). The player walks at ~100.
@export var current_strength: float = 40.0
@export var flip_time: float = 7.0
## Seconds the current takes to die down and pick up again around a flip.
@export var flip_ease: float = 1.2
## Pull towards the drain mouth while suction is on (px/s).
@export var suction_strength: float = 62.0
## Shots get this many px/s of sideways speed added per second they spend in the water.
@export var projectile_drift: float = 1.6
## Rubbish is light: pushed this much harder than the player.
@export var rubbish_mult: float = 1.8
@export var fade_time: float = 1.5

const WATER_COL := Color(0.32, 0.4, 0.28)
const STREAK_COL := Color(0.75, 0.85, 0.7)
const STREAKS := 34

var area: Rect2          # global floor rect
var drain_pos: Vector2   # global drain mouth
var drain_dir: Vector2   # from the room's middle towards the drain wall
var boss: Node = null    # never pushed

var level: float = 0.0   # 0 = dry, 1 = flooded
var _target_level: float = 1.0
var _side: Vector2       # current direction (unit, along the drain wall)
var _flip_timer: float = 0.0
var _suction_left: float = 0.0
var _suction_warn: float = 0.0
var _t: float = 0.0
var _streaks: Array = []  # [Vector2 local pos, float phase]


func setup(floor_rect: Rect2, mouth: Vector2, dir_to_drain: Vector2, owner_boss: Node) -> void:
	area = floor_rect
	drain_pos = mouth
	drain_dir = dir_to_drain
	boss = owner_boss
	_side = drain_dir.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
	_flip_timer = flip_time
	global_position = Vector2.ZERO
	for i in STREAKS:
		_streaks.append([Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y)), randf()])


## Water goes away (phase 3 / boss dead), then the node frees itself.
func drain_away() -> void:
	_target_level = 0.0
	_suction_left = 0.0


func warn_suction(seconds: float) -> void:
	_suction_warn = seconds


func start_suction(seconds: float) -> void:
	_suction_warn = 0.0
	_suction_left = seconds


func is_sucking() -> bool:
	return _suction_left > 0.0


## Current right now (px/s), eased to 0 around each flip.
func current_velocity() -> Vector2:
	var ease_t := 1.0
	if _flip_timer < flip_ease * 0.5:
		ease_t = _flip_timer / (flip_ease * 0.5)
	elif _flip_timer > flip_time - flip_ease * 0.5:
		ease_t = (flip_time - _flip_timer) / (flip_ease * 0.5)
	return _side * current_strength * clampf(ease_t, 0.0, 1.0) * level


func push_at(pos: Vector2) -> Vector2:
	var push := current_velocity()
	if _suction_left > 0.0:
		var to_mouth := drain_pos - pos
		if to_mouth.length() > 4.0:
			push = push * 0.3 + to_mouth.normalized() * suction_strength * level
	return push


func _physics_process(delta: float) -> void:
	_t += delta
	level = move_toward(level, _target_level, delta / fade_time)
	if _target_level <= 0.0 and level <= 0.0:
		queue_free()
		return
	_flip_timer -= delta
	if _flip_timer <= 0.0:
		_flip_timer = flip_time
		_side = -_side
	if _suction_left > 0.0:
		_suction_left -= delta
	if _suction_warn > 0.0:
		_suction_warn -= delta
	_apply_forces(delta)
	_move_streaks(delta)
	queue_redraw()


func _apply_forces(delta: float) -> void:
	if level <= 0.01:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.has_method("add_external_push") and area.has_point(player.global_position):
		player.add_external_push(push_at(player.global_position))
	var entities := player.get_parent() if player else null
	if entities:
		for e in entities.get_children():
			if e == boss or not (e is EnemyBase) or (e as EnemyBase).is_boss:
				continue
			if area.has_point(e.global_position):
				(e as EnemyBase).add_external_push(push_at(e.global_position))
	for p in get_tree().get_nodes_in_group("projectiles"):
		if "velocity" in p and area.has_point(p.global_position):
			p.velocity += push_at(p.global_position) * projectile_drift * delta
	for r in get_tree().get_nodes_in_group("clog_rubbish"):
		if area.has_point(r.global_position):
			r.add_external_push(push_at(r.global_position) * rubbish_mult)


func _move_streaks(delta: float) -> void:
	for s in _streaks:
		var pos: Vector2 = s[0]
		var v := push_at(pos)
		if v.length() < 4.0:
			v = v.normalized() * 4.0 if v != Vector2.ZERO else _side * 4.0
		pos += v * 1.6 * delta
		if not area.grow(-2.0).has_point(pos) or (_suction_left > 0.0 and pos.distance_to(drain_pos) < 10.0):
			pos = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		s[0] = pos


func _draw() -> void:
	if level <= 0.0:
		return
	var a := level
	draw_rect(area, Color(WATER_COL, 0.38 * a))
	for s in _streaks:
		var pos: Vector2 = s[0]
		var v := push_at(pos)
		var dir := v.normalized() if v.length() > 1.0 else _side
		var streak_len := 4.0 + v.length() * 0.12
		var wob := sin(_t * 3.0 + float(s[1]) * TAU) * 1.2
		var start := pos + dir.orthogonal() * wob
		draw_line(start, start + dir * streak_len, Color(STREAK_COL, 0.45 * a), 1.0)
	# Suction warning: rings shrinking into the drain.
	if _suction_warn > 0.0 or _suction_left > 0.0:
		for i in 3:
			var r := fmod(_t * 60.0 + i * 22.0, 66.0)
			r = 66.0 - r
			draw_arc(drain_pos, r + 6.0, 0.0, TAU, 32, Color(0.85, 0.95, 0.85, 0.5 * a * (1.0 if _suction_left > 0.0 else 0.6)), 1.5)
