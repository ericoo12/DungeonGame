class_name EnemySpawnPlanner
extends RefCounted

## Picks enemy spawn cells procedurally from a room's RoomGrid (no hand-placed markers).
##
## Candidate cells must be:
##   - reachable from the doors (BFS over the grid, obstacles included) -> no enemy can
##     be sealed off, so the room can always be cleared
##   - fully surrounded by walkable cells (keeps bodies out of walls/obstacles)
##   - at least min_entry_distance cells from every door entry point (no spawning on
##     top of the player as they walk in)
## Among candidates, positions are chosen with best-candidate sampling: for each enemy,
## draw `samples` random candidates and keep the one farthest from the enemies already
## placed. Gives an even-but-random spread instead of clumps.

const NEIGHBORS_8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]


static func pick_cells(grid: RoomGrid, entry_cells: Array[Vector2i], count: int,
		min_entry_distance: float, samples: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if count <= 0:
		return result

	var reachable: Array = _reachable_cells(grid, entry_cells)

	# Relax constraints step by step if the room is too cramped for the full set.
	var candidates := _filter(grid, reachable, entry_cells, min_entry_distance, true)
	if candidates.size() < count:
		candidates = _filter(grid, reachable, entry_cells, min_entry_distance * 0.5, true)
	if candidates.size() < count:
		candidates = _filter(grid, reachable, entry_cells, min_entry_distance * 0.5, false)
	if candidates.is_empty():
		push_warning("EnemySpawnPlanner: no valid spawn cells in room")
		return result

	for i in mini(count, candidates.size()):
		var best: Vector2i = candidates[randi() % candidates.size()]
		var best_dist := _min_distance(best, result)
		for s in range(1, maxi(samples, 1)):
			var cell: Vector2i = candidates[randi() % candidates.size()]
			var d := _min_distance(cell, result)
			if d > best_dist:
				best = cell
				best_dist = d
		result.append(best)
		candidates.erase(best)
	return result


static func _reachable_cells(grid: RoomGrid, entry_cells: Array[Vector2i]) -> Array:
	for entry in entry_cells:
		var reached := grid.bfs(entry)
		if not reached.is_empty():
			return reached.keys()
	# No usable entry (shouldn't happen in a normal room): fall back to every walkable cell.
	var all: Array = []
	for x in range(grid.rect.position.x, grid.rect.end.x):
		for y in range(grid.rect.position.y, grid.rect.end.y):
			if grid.is_walkable(Vector2i(x, y)):
				all.append(Vector2i(x, y))
	return all


static func _filter(grid: RoomGrid, cells: Array, entry_cells: Array[Vector2i],
		min_entry_distance: float, need_clearance: bool) -> Array:
	var out: Array = []
	for cell in cells:
		if _min_distance(cell, entry_cells) < min_entry_distance:
			continue
		if need_clearance and not _has_clearance(grid, cell):
			continue
		out.append(cell)
	return out


static func _has_clearance(grid: RoomGrid, cell: Vector2i) -> bool:
	for offset in NEIGHBORS_8:
		if not grid.is_walkable(cell + offset):
			return false
	return true


## Euclidean distance (in cells) to the nearest cell in `others`; INF if none.
static func _min_distance(cell: Vector2i, others: Array) -> float:
	var best := INF
	for other in others:
		best = minf(best, Vector2(cell - other).length())
	return best
