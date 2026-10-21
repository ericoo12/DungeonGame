class_name ObstaclePlacer
extends RefCounted

## Search-validated procedural obstacle placement ("generate and test").
##
##   1. Generate N candidate layouts: each usable marker independently gets an
##      obstacle with probability spawn_chance, breakable or solid by breakable_ratio.
##   2. Reject any candidate that breaks a hard constraint: every key cell (door entry
##      points + enemy spawn points) must stay reachable from every other, treating ALL
##      obstacles as blocking. Breakables count as blocking on purpose: enemies can't
##      break them, and the player shouldn't be forced to.
##   3. Score the survivors (density close to target, little crowding around doors,
##      short detours between doors) and keep the best one.
##
## With validate = false it falls back to a single unchecked random roll, which is
## useful for comparing against the validated version.

const CROWD_RADIUS := 4          # obstacles closer than this (Manhattan cells) to an entry get penalized
const W_DENSITY := 2.0
const W_CROWDING := 0.5
const W_DETOUR := 3.0


## Returns { marker_index: { "scene_path": String, "broken": false } }.
## entry_cells: door entry points (used for scoring + constraints).
## required_cells: other cells that must stay reachable (e.g. enemy spawns).
## clear_cells: cells no obstacle may occupy (entry/spawn clearance).
static func generate(
		grid: RoomGrid,
		marker_cells: Array[Vector2i],
		entry_cells: Array[Vector2i],
		required_cells: Array[Vector2i],
		clear_cells: Dictionary,
		breakable_scenes: Array[PackedScene],
		solid_scenes: Array[PackedScene],
		spawn_chance: float,
		breakable_ratio: float,
		candidate_count: int,
		validate: bool = true) -> Dictionary:

	if breakable_scenes.is_empty() and solid_scenes.is_empty():
		return {}

	# Markers that can ever hold an obstacle (not on a wall, not in a clearance zone,
	# not duplicated onto an already-used cell).
	var usable: Array[int] = []
	var seen_cells: Dictionary = {}
	for i in marker_cells.size():
		var cell: Vector2i = marker_cells[i]
		if seen_cells.has(cell) or clear_cells.has(cell) or not grid.is_walkable(cell):
			continue
		seen_cells[cell] = true
		usable.append(i)

	if not validate:
		return _to_state(_random_candidate(usable, breakable_scenes, solid_scenes, spawn_chance, breakable_ratio))

	var key_cells: Array[Vector2i] = entry_cells.duplicate()
	key_cells.append_array(required_cells)
	var target_count: float = spawn_chance * usable.size()
	var baseline_detour: float = _entry_path_length(grid, entry_cells, {})

	var best: Dictionary = {}
	var best_score := -INF
	var valid_count := 0
	for _attempt in maxi(candidate_count, 1):
		var candidate := _random_candidate(usable, breakable_scenes, solid_scenes, spawn_chance, breakable_ratio)
		var blocked := _blocked_set(candidate, marker_cells)
		if not _all_connected(grid, key_cells, blocked):
			continue
		valid_count += 1
		var score := _score(grid, candidate.size(), target_count, blocked, entry_cells, baseline_detour)
		if score > best_score:
			best_score = score
			best = candidate

	if valid_count == 0:
		push_warning("ObstaclePlacer: no valid layout in %d candidates, room gets no obstacles" % candidate_count)
	return _to_state(best)


# --- Candidate generation --------------------------------------------------

## { marker_index: PackedScene }
static func _random_candidate(usable: Array[int], breakable_scenes: Array[PackedScene],
		solid_scenes: Array[PackedScene], spawn_chance: float, breakable_ratio: float) -> Dictionary:
	var candidate: Dictionary = {}
	for i in usable:
		if randf() >= spawn_chance:
			continue
		var want_breakable := randf() < breakable_ratio
		if breakable_scenes.is_empty():
			want_breakable = false
		elif solid_scenes.is_empty():
			want_breakable = true
		var pool: Array[PackedScene] = breakable_scenes if want_breakable else solid_scenes
		candidate[i] = pool[randi() % pool.size()]
	return candidate


static func _blocked_set(candidate: Dictionary, marker_cells: Array[Vector2i]) -> Dictionary:
	var blocked: Dictionary = {}
	for i in candidate:
		blocked[marker_cells[i]] = true
	return blocked


static func _to_state(candidate: Dictionary) -> Dictionary:
	var state: Dictionary = {}
	for i in candidate:
		state[i] = {"scene_path": candidate[i].resource_path, "broken": false}
	return state


# --- Constraint: reachability ---------------------------------------------

## One flood fill from the first key cell; everything else must be in it.
static func _all_connected(grid: RoomGrid, key_cells: Array[Vector2i], blocked: Dictionary) -> bool:
	if key_cells.size() < 2:
		return true
	var reached := grid.bfs(key_cells[0], blocked)
	for cell in key_cells:
		if not reached.has(cell):
			return false
	return true


# --- Scoring ---------------------------------------------------------------

static func _score(grid: RoomGrid, count: int, target_count: float, blocked: Dictionary,
		entry_cells: Array[Vector2i], baseline_detour: float) -> float:
	# 1. Density: close to what spawn_chance asks for (otherwise "no obstacles" always wins).
	var density_penalty := absf(count - target_count)

	# 2. Crowding: obstacles hugging the doors feel bad to walk into.
	var crowding_penalty := 0.0
	for cell in blocked:
		for entry in entry_cells:
			var d: int = absi(cell.x - entry.x) + absi(cell.y - entry.y)
			if d < CROWD_RADIUS:
				crowding_penalty += CROWD_RADIUS - d

	# 3. Detour: how much longer door-to-door walks get compared to the empty room.
	var detour_penalty := 0.0
	if baseline_detour > 0.0:
		detour_penalty = _entry_path_length(grid, entry_cells, blocked) / baseline_detour - 1.0

	return -W_DENSITY * density_penalty - W_CROWDING * crowding_penalty - W_DETOUR * detour_penalty


## Sum of shortest-path lengths between every pair of entries (one BFS per entry).
static func _entry_path_length(grid: RoomGrid, entry_cells: Array[Vector2i], blocked: Dictionary) -> float:
	var total := 0.0
	for a in entry_cells.size():
		var dist := grid.bfs(entry_cells[a], blocked)
		for b in range(a + 1, entry_cells.size()):
			total += dist.get(entry_cells[b], 0)
	return total
