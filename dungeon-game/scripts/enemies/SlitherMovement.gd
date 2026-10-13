# SlitherMovement.gd — wanders like a snake: smooth turns, sideways S-wave, steers away
# from walls/obstacles (room grid), and drifts toward the player when they're near.
# Per-enemy state lives here; EnemyBase duplicates the resource for every enemy.
class_name SlitherMovement
extends MovementBehavior

@export var turn_speed_deg: float = 120.0            # max body turn per second (no snapping)
@export var wander_change_interval: Vector2 = Vector2(1.0, 2.5)  # new random goal every min..max s
@export var notice_radius: float = 140.0             # within this, it leans toward the player...
@export_range(0.0, 1.0) var player_bias: float = 0.5 # ...this much (0 = ignore, 1 = head straight at)
@export var wobble_amount: float = 0.4               # S-wave strength (sideways)
@export var wobble_frequency: float = 2.5            # S-waves per second
@export var wall_look_ahead: float = 18.0            # px ahead it checks for walls/obstacles
## After bumping a wall it ignores the player for this long, so it can't keep
## steering back into a wall that's between it and the player.
@export var wall_avoid_time: float = 1.0
## Moved less than this (px) over STUCK_CHECK_TIME while trying to move = stuck.
@export var stuck_distance: float = 3.0

var _heading: Vector2 = Vector2.ZERO
var _wander_goal: Vector2 = Vector2.RIGHT
var _timer: float = 0.0
var _phase: float = 0.0
var _avoid_timer: float = 0.0
var _stuck_timer: float = 0.0
var _stuck_check_pos: Vector2 = Vector2.INF

const STUCK_CHECK_TIME := 0.4
const SOLID_MASK := 1  # walls (WallBlockers) + obstacles share physics layer 1


func get_velocity(enemy: EnemyBase, delta: float) -> Vector2:
	if _heading == Vector2.ZERO:
		_heading = Vector2.RIGHT.rotated(randf() * TAU)
		_wander_goal = _heading
		_phase = randf() * TAU

	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(wander_change_interval.x, wander_change_interval.y)
		_wander_goal = Vector2.RIGHT.rotated(randf() * TAU)

	var pos := enemy.global_position
	_avoid_timer -= delta

	# Physically touching a wall/obstacle (last move_and_slide) and heading into it:
	# turn along the wall, away from it. Catches walls the grid look-ahead misses
	# (wall shapes that only cover part of a 16 px cell).
	var wall_normal := _wall_contact_normal(enemy)
	if wall_normal != Vector2.ZERO and _heading.dot(wall_normal) < -0.2 \
			and (_avoid_timer <= 0.0 or _wander_goal.dot(wall_normal) < 0.0):
		_turn_away(wall_normal)
	_check_stuck(enemy, pos, delta)

	var goal := _wander_goal
	if enemy.player and _avoid_timer <= 0.0:
		var to_player := enemy.get_player_aim_point() - pos
		if to_player.length() < notice_radius:
			goal = goal.lerp(to_player.normalized(), player_bias).normalized()

	# Wall/obstacle ahead: turn toward whichever side is open (or turn around).
	var grid := RoomGrid.current()
	# Already turning toward an open escape direction: keep it (re-rolling every frame
	# while the body is still turning would flip-flop left/right and stall at the wall).
	var escaping := _avoid_timer > 0.0 and _clear(enemy, grid, pos, _wander_goal)
	if escaping:
		goal = _wander_goal
	elif not _clear(enemy, grid, pos, _heading):
		var left := _heading.rotated(-PI / 2.0)
		var right := _heading.rotated(PI / 2.0)
		# Random side first so snakes don't all hug walls the same way.
		if randf() < 0.5:
			var tmp := left
			left = right
			right = tmp
		if _clear(enemy, grid, pos, left):
			goal = left
		elif _clear(enemy, grid, pos, right):
			goal = right
		else:
			goal = -_heading
		_wander_goal = goal
		_avoid_timer = wall_avoid_time

	var max_turn := deg_to_rad(turn_speed_deg) * delta
	_heading = _heading.rotated(clampf(_heading.angle_to(goal), -max_turn, max_turn))

	_phase += delta * wobble_frequency * TAU
	var dir := (_heading + _heading.orthogonal() * sin(_phase) * wobble_amount).normalized()
	enemy._update_facing_direction(_heading)  # body direction, not the S-wave, so art doesn't flicker
	return dir * enemy.move_speed


static func _open(grid: RoomGrid, point: Vector2) -> bool:
	return grid.is_walkable(grid.global_to_cell(point))


## Free `wall_look_ahead` px in `dir`: on the room grid AND by a physics ray
## (the ray sees the real wall shapes, the grid only whole cells).
func _clear(enemy: EnemyBase, grid: RoomGrid, pos: Vector2, dir: Vector2) -> bool:
	var ahead := pos + dir * wall_look_ahead
	if grid and not _open(grid, ahead):
		return false
	var query := PhysicsRayQueryParameters2D.create(pos, ahead, SOLID_MASK, [enemy.get_rid()])
	return enemy.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Normal of a wall/obstacle the body slid against last frame (ignores the player
## and other enemies). ZERO if none.
static func _wall_contact_normal(enemy: EnemyBase) -> Vector2:
	for i in enemy.get_slide_collision_count():
		var col := enemy.get_slide_collision(i)
		var other := col.get_collider()
		if other is CharacterBody2D:
			continue
		return col.get_normal()
	return Vector2.ZERO


## New goal along the wall (random side, tilted away from it); ignore the player a bit.
func _turn_away(normal: Vector2) -> void:
	var along := normal.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
	_wander_goal = (along + normal * 0.6).normalized()
	_avoid_timer = wall_avoid_time
	_timer = randf_range(wander_change_interval.x, wander_change_interval.y)


## Last resort: barely moved for a while -> snap to a fresh random open direction.
func _check_stuck(enemy: EnemyBase, pos: Vector2, delta: float) -> void:
	if enemy.forced_velocity_active or enemy.action_state != "":
		_stuck_check_pos = Vector2.INF  # lunging/attacking: standing still is intended
		return
	if _stuck_check_pos == Vector2.INF:
		_stuck_check_pos = pos
		_stuck_timer = 0.0
		return
	_stuck_timer += delta
	if _stuck_timer < STUCK_CHECK_TIME:
		return
	if pos.distance_to(_stuck_check_pos) < stuck_distance:
		var grid := RoomGrid.current()
		for i in 8:
			var dir := Vector2.RIGHT.rotated(randf() * TAU)
			if _clear(enemy, grid, pos, dir):
				_heading = dir
				_wander_goal = dir
				break
		_avoid_timer = wall_avoid_time
		_timer = randf_range(wander_change_interval.x, wander_change_interval.y)
	_stuck_check_pos = pos
	_stuck_timer = 0.0
