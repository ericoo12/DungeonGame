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

var _heading: Vector2 = Vector2.ZERO
var _wander_goal: Vector2 = Vector2.RIGHT
var _timer: float = 0.0
var _phase: float = 0.0


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
	var goal := _wander_goal
	if enemy.player:
		var to_player := enemy.get_player_aim_point() - pos
		if to_player.length() < notice_radius:
			goal = goal.lerp(to_player.normalized(), player_bias).normalized()

	# Wall/obstacle ahead: turn toward whichever side is open (or turn around).
	var grid := RoomGrid.current()
	if grid and not _open(grid, pos + _heading * wall_look_ahead):
		var left := _heading.rotated(-PI / 2.0)
		var right := _heading.rotated(PI / 2.0)
		if _open(grid, pos + left * wall_look_ahead):
			goal = left
		elif _open(grid, pos + right * wall_look_ahead):
			goal = right
		else:
			goal = -_heading
		_wander_goal = goal

	var max_turn := deg_to_rad(turn_speed_deg) * delta
	_heading = _heading.rotated(clampf(_heading.angle_to(goal), -max_turn, max_turn))

	_phase += delta * wobble_frequency * TAU
	var dir := (_heading + _heading.orthogonal() * sin(_phase) * wobble_amount).normalized()
	enemy._update_facing_direction(_heading)  # body direction, not the S-wave, so art doesn't flicker
	return dir * enemy.move_speed


static func _open(grid: RoomGrid, point: Vector2) -> bool:
	return grid.is_walkable(grid.global_to_cell(point))
