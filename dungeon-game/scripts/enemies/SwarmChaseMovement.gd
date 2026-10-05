## SwarmChaseMovement.gd — pack/swarm chaser (rats). Reusable on any enemy.
##
## Each member steers by blending:
##   - SEEK: toward the player. Far away, every member aims for its OWN spot on a ring
##     around the player (stable per enemy), so the swarm spreads out and surrounds
##     instead of forming a conga line. Within commit_distance it charges straight in.
##     If the straight line is blocked (walls/obstacles on the room grid) it follows a
##     shared flow field (BFS from the player's cell), so the swarm pours around obstacles.
##   - BOIDS: separation (don't stack), alignment (run the same way as neighbours),
##     cohesion (stay together). Neighbours = other enemies in the same swarm_group.
##   - FEEL: smoothed turning + a small sideways "scurry" wobble.
## Damage is EnemyBase's contact damage (Hitbox vs player HurtBox); no AttackBehavior needed.
##
## The resource keeps NO per-enemy state (per-enemy variation comes from the instance
## id), so one .tres can safely be shared by every enemy that uses it.
class_name SwarmChaseMovement
extends MovementBehavior

## Enemies with the same group name flock together (e.g. rats with rats).
@export var swarm_group: StringName = &"swarm"

@export_group("Seek")
@export var surround_radius: float = 28.0   # far away: each member heads for its own point on this ring
@export var commit_distance: float = 44.0   # closer than this: charge straight at the player
@export var speed_variance: float = 0.15    # ±15% speed per member, so they don't move in lockstep

@export_group("Boids")
@export var neighbor_radius: float = 40.0
@export var separation_radius: float = 12.0
@export var w_seek: float = 1.0
@export var w_separation: float = 1.6
@export var w_alignment: float = 0.35
@export var w_cohesion: float = 0.25

@export_group("Feel")
@export var turn_rate: float = 8.0          # higher = snappier direction changes
@export var scurry_amount: float = 0.35     # sideways wobble strength
@export var scurry_frequency: float = 9.0

const FIELD_REFRESH_FRAMES := 15  # also recomputed whenever the player changes cell

# Flow field shared by every member (one BFS per room per refresh, not one per rat).
static var _field: Dictionary = {}
static var _field_grid: RoomGrid = null
static var _field_target: Vector2i = Vector2i(1 << 20, 1 << 20)
static var _field_frame: int = -1000


func get_velocity(enemy: EnemyBase, delta: float) -> Vector2:
	if enemy.player == null:
		return Vector2.ZERO
	if not enemy.is_in_group(swarm_group):
		enemy.add_to_group(swarm_group)

	# Stable 0..1 value per enemy: its spot on the ring, wobble phase and speed.
	var personal := float(enemy.get_instance_id() % 997) / 997.0
	var pos := enemy.global_position

	# --- Seek ---
	var player_point := enemy.get_player_aim_point()
	var target := player_point
	if pos.distance_to(player_point) > commit_distance:
		target += Vector2.RIGHT.rotated(personal * TAU) * surround_radius
	var seek := _seek_direction(pos, target, player_point)

	# --- Boids ---
	var separation := Vector2.ZERO
	var alignment := Vector2.ZERO
	var center := Vector2.ZERO
	var neighbors := 0
	for node in enemy.get_tree().get_nodes_in_group(swarm_group):
		var other := node as EnemyBase
		if other == null or other == enemy or other.is_dying:
			continue
		var offset := pos - other.global_position
		var d := offset.length()
		if d > neighbor_radius or d < 0.001:
			continue
		neighbors += 1
		alignment += other.velocity
		center += other.global_position
		if d < separation_radius:
			separation += offset / d * (1.0 - d / separation_radius)

	var desired := seek * w_seek + separation * w_separation
	if neighbors > 0:
		desired += (alignment / neighbors).normalized() * w_alignment
		desired += (center / neighbors - pos).normalized() * w_cohesion

	# --- Feel ---
	if desired.length_squared() > 0.0001:
		desired = desired.normalized()
		var t := Time.get_ticks_msec() / 1000.0
		desired = (desired + desired.orthogonal() * sin(t * scurry_frequency + personal * TAU) * scurry_amount).normalized()

	var speed := enemy.move_speed * (1.0 + (personal - 0.5) * 2.0 * speed_variance)
	var velocity := enemy.velocity.lerp(desired * speed, clampf(turn_rate * delta, 0.0, 1.0))
	if velocity.length() > 1.0:
		enemy._update_facing_direction(velocity.normalized())
	return velocity


## Straight at `target` if the line there is clear on the room grid; otherwise follow
## the shared flow field toward the player.
func _seek_direction(from: Vector2, target: Vector2, player_point: Vector2) -> Vector2:
	var grid := _current_grid()
	if grid == null or _line_clear(grid, from, target):
		return (target - from).normalized()

	var field := _flow_field(grid, grid.global_to_cell(player_point))
	var cell := grid.global_to_cell(from)
	if not field.has(cell):
		return (target - from).normalized()

	var best := cell
	var best_dist: int = field[cell]
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var next: Vector2i = cell + offset
		if not field.has(next):
			continue
		# Diagonals only if both side cells are open (no corner cutting).
		if offset.x != 0 and offset.y != 0:
			if not field.has(Vector2i(next.x, cell.y)) or not field.has(Vector2i(cell.x, next.y)):
				continue
		if field[next] < best_dist:
			best_dist = field[next]
			best = next
	if best == cell:
		return (target - from).normalized()
	return (grid.cell_to_global(best) - from).normalized()


static func _flow_field(grid: RoomGrid, target_cell: Vector2i) -> Dictionary:
	var frame := Engine.get_physics_frames()
	if grid != _field_grid or target_cell != _field_target or frame - _field_frame >= FIELD_REFRESH_FRAMES:
		_field = grid.bfs(target_cell)
		_field_grid = grid
		_field_target = target_cell
		_field_frame = frame
	return _field


static func _line_clear(grid: RoomGrid, from: Vector2, to: Vector2) -> bool:
	var steps := ceili(from.distance_to(to) / 8.0)
	for i in range(1, steps + 1):
		if not grid.is_walkable(grid.global_to_cell(from.lerp(to, float(i) / steps))):
			return false
	return true


static func _current_grid() -> RoomGrid:
	var tree := Engine.get_main_loop() as SceneTree
	var dungeon := tree.get_first_node_in_group("dungeon") as Dungeon if tree else null
	if dungeon == null:
		return null
	var room := dungeon.current_room as RoomController
	return room.grid if room else null
