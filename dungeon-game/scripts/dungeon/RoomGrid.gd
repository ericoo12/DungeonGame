class_name RoomGrid
extends RefCounted

## Walkability grid for one room: 16x16 cells in the room's local space (cell (0,0) has
## its top-left corner at the room origin). Starts fully open inside `rect`; walls are
## added from RoomBase's WallBlockers collision shapes (block_rect), obstacles via
## set_obstacle. No TileMap needed.
##
## Used by ObstaclePlacer / EnemySpawnPlanner, and meant to be shared with enemy
## pathfinding: RoomController.grid.to_astar() gives an AStarGrid2D that agrees with
## what placement considered walkable. Kept up to date when obstacles break.

const CELL_SIZE := 16.0
const NEIGHBORS_4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var origin: Node2D                   # the room; cells are laid out in its local space
var rect: Rect2i                     # cells the grid covers
var wall_cells: Dictionary = {}      # Vector2i -> true
var obstacle_cells: Dictionary = {}  # Vector2i -> true


func _init(room: Node2D, cell_rect: Rect2i) -> void:
	origin = room
	rect = cell_rect


# --- Coordinate conversion -------------------------------------------------

func global_to_cell(global_pos: Vector2) -> Vector2i:
	var local := origin.to_local(global_pos)
	return Vector2i(floori(local.x / CELL_SIZE), floori(local.y / CELL_SIZE))


func cell_to_global(cell: Vector2i) -> Vector2:
	return origin.to_global((Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE)


# --- Walkability -----------------------------------------------------------

func is_walkable(cell: Vector2i, extra_blocked: Dictionary = {}) -> bool:
	return rect.has_point(cell) \
		and not wall_cells.has(cell) \
		and not obstacle_cells.has(cell) \
		and not extra_blocked.has(cell)


## Marks every cell whose CENTER lies inside `global_rect` as wall.
func block_rect(global_rect: Rect2) -> void:
	var first := global_to_cell(global_rect.position)
	var last := global_to_cell(global_rect.end)
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			var cell := Vector2i(x, y)
			if global_rect.has_point(cell_to_global(cell)):
				wall_cells[cell] = true


func set_obstacle(cell: Vector2i, present: bool) -> void:
	if present:
		obstacle_cells[cell] = true
	else:
		obstacle_cells.erase(cell)


## Breadth-first flood fill from `start`. Returns { cell: steps_from_start } for every
## reachable cell. `extra_blocked` lets callers test a hypothetical obstacle layout
## without touching obstacle_cells.
func bfs(start: Vector2i, extra_blocked: Dictionary = {}) -> Dictionary:
	var dist: Dictionary = {}
	if not is_walkable(start, extra_blocked):
		return dist
	dist[start] = 0
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for offset in NEIGHBORS_4:
			var next: Vector2i = current + offset
			if dist.has(next) or not is_walkable(next, extra_blocked):
				continue
			dist[next] = dist[current] + 1
			queue.append(next)
	return dist


## For enemy pathfinding. Solid points = walls + current obstacles.
## Call again (or set_point_solid) after an obstacle breaks; RoomController emits
## obstacle_layout_changed when that happens.
## Usage: astar.get_point_path(grid.global_to_cell(a), grid.global_to_cell(b)) returns
## room-local points; convert with room.to_global(p).
func to_astar() -> AStarGrid2D:
	var astar := AStarGrid2D.new()
	astar.region = rect
	astar.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	astar.offset = astar.cell_size / 2.0  # get_point_position() = room-local cell center
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if not is_walkable(cell):
				astar.set_point_solid(cell, true)
	return astar
