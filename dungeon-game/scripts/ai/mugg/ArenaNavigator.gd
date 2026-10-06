class_name ArenaNavigator
extends Node

## Collision-sampled grid; respects room transforms and the actor's clearance.
## Explicit update only, no autonomous movement or physics callback.
const MOVEMENT_MASK: int = 1 | (1 << 7)
var arena: RoomController
var actor: Node2D
var radius: float = 20.0
var cell_size: float = 16.0
var grid := AStarGrid2D.new()
var bounds: Rect2
var path := PackedVector2Array()
var goal: Vector2
var ready_for_paths: bool = false
var _refresh_timer: float = 0.0
var _open_cells: Array[Vector2i] = []

func configure(body: Node2D, room: RoomController, clearance: float) -> void:
	actor = body
	arena = room
	radius = maxf(1.0, clearance)
	ready_for_paths = false
	path.clear()
	_refresh_timer = 0.0

func update(delta: float) -> void:
	if not is_instance_valid(arena):
		ready_for_paths = false
		path.clear()
		return
	_refresh_timer -= delta
	if not ready_for_paths or _refresh_timer <= 0.0:
		var had_path := not path.is_empty()
		rebuild()
		if had_path:
			path = path_to(actor.global_position, goal)

func rebuild() -> void:
	bounds = arena.get_arena_bounds().grow(-radius)
	ready_for_paths = false
	_open_cells.clear()
	path.clear()
	_refresh_timer = 1.0
	if bounds.size.x < cell_size or bounds.size.y < cell_size:
		return
	grid.region = Rect2i(Vector2i.ZERO, Vector2i(floori(bounds.size.x / cell_size) + 1, floori(bounds.size.y / cell_size) + 1))
	grid.cell_size = Vector2.ONE * cell_size
	grid.offset = bounds.position
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var id := Vector2i(x, y)
			var blocked := not position_clear(grid.get_point_position(id))
			grid.set_point_solid(id, blocked)
			if not blocked:
				_open_cells.append(id)
	ready_for_paths = true

func _query(position: Vector2, clearance: float) -> PhysicsShapeQueryParameters2D:
	var shape := CircleShape2D.new()
	shape.radius = clearance
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, position)
	query.collision_mask = MOVEMENT_MASK
	return query

func position_clear(position: Vector2) -> bool:
	if not bounds.has_point(position):
		return false
	return actor.get_world_2d().direct_space_state.intersect_shape(_query(position, radius), 1).is_empty()

func segment_clear(from: Vector2, to: Vector2) -> bool:
	if not position_clear(from) or not position_clear(to):
		return false
	var query := _query(from, radius)
	query.motion = to - from
	var result := actor.get_world_2d().direct_space_state.cast_motion(query)
	return result[0] >= 0.999

func _nearest_cell(position: Vector2, require_connection: bool) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for id in _open_cells:
		var point := grid.get_point_position(id)
		var distance := point.distance_squared_to(position)
		if distance < best_distance and (not require_connection or segment_clear(position, point)):
			best = id
			best_distance = distance
	return best

func path_to(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not ready_for_paths or not position_clear(to):
		return PackedVector2Array()
	if segment_clear(from, to):
		return PackedVector2Array([to])
	var start := _nearest_cell(from, true)
	var end := _nearest_cell(to, true)
	if start.x < 0 or end.x < 0:
		return PackedVector2Array()
	var result := grid.get_point_path(start, end)
	if result.is_empty():
		return result
	# Validate swept clearance along grid edges as well as at sample points.
	for i in range(1, result.size()):
		if not segment_clear(result[i - 1], result[i]):
			return PackedVector2Array()
	result.append(to)
	return result

func set_path(points: PackedVector2Array) -> void:
	path = points
	if not path.is_empty():
		goal = path[-1]

func stop() -> void:
	path.clear()

func desired_velocity(position: Vector2, speed: float, delta: float) -> Vector2:
	while not path.is_empty() and position.distance_to(path[0]) < 3.0:
		path.remove_at(0)
	if path.is_empty():
		return Vector2.ZERO
	# Smooth only when the actor's full footprint fits along the shortcut.
	while path.size() > 1 and segment_clear(position, path[1]):
		path.remove_at(0)
	if not segment_clear(position, path[0]):
		path.clear()
		return Vector2.ZERO
	var offset := path[0] - position
	return offset.normalized() * minf(speed, offset.length() / maxf(delta, 0.001))
