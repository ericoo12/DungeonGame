class_name DungeonGenerator
extends RefCounted

const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)
const EAST := Vector2i(1, 0)
const WEST := Vector2i(-1, 0)
const DIRECTIONS := [NORTH, SOUTH, EAST, WEST]


static func generate(room_count: int) -> Dictionary:
	var layout: Dictionary = {}
	var start_pos := Vector2i.ZERO

	var start_data := RoomData.new()
	start_data.grid_pos = start_pos
	start_data.type = RoomData.Type.START
	start_data.cleared = true
	layout[start_pos] = start_data

	var frontier: Array[Vector2i] = [start_pos]
	var attempts := 0
	var max_attempts := room_count * 20

	while layout.size() < room_count and attempts < max_attempts:
		attempts += 1
		var from: Vector2i = frontier[randi() % frontier.size()]
		var dir: Vector2i = DIRECTIONS[randi() % DIRECTIONS.size()]
		var next: Vector2i = from + dir
		if layout.has(next):
			continue

		var data := RoomData.new()
		data.grid_pos = next
		data.type = RoomData.Type.NORMAL
		layout[next] = data
		frontier.append(next)

	_assign_doors(layout)
	var distances: Dictionary = _bfs_distances(layout, start_pos)
	_assign_boss_room_from_distances(layout, distances)
	_assign_item_room_from_distances(layout, distances)
	return {"layout": layout, "distances": distances}


static func _assign_doors(layout: Dictionary) -> void:
	for pos in layout.keys():
		var data: RoomData = layout[pos]
		for dir in DIRECTIONS:
			data.doors[dir] = layout.has(pos + dir)


static func _assign_boss_room_from_distances(layout: Dictionary, distances: Dictionary) -> void:
	var best_pos: Vector2i = Vector2i.ZERO
	var best_dist := -1

	for pos in layout.keys():
		var data: RoomData = layout[pos]
		if data.type != RoomData.Type.NORMAL:
			continue
		var connections := 0
		for dir in DIRECTIONS:
			if data.doors[dir]:
				connections += 1
		if connections == 1 and distances.get(pos, 0) > best_dist:
			best_dist = distances[pos]
			best_pos = pos

	if best_dist == -1:
		for pos in layout.keys():
			if layout[pos].type == RoomData.Type.NORMAL and distances.get(pos, 0) > best_dist:
				best_dist = distances[pos]
				best_pos = pos

	if layout.has(best_pos):
		layout[best_pos].type = RoomData.Type.BOSS


static func _bfs_distances(layout: Dictionary, start_pos: Vector2i) -> Dictionary:
	var distances: Dictionary = {start_pos: 0}
	var queue: Array[Vector2i] = [start_pos]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var current_data: RoomData = layout[current]
		for dir in DIRECTIONS:
			if not current_data.doors[dir]:
				continue
			var neighbor: Vector2i = current + dir
			if not distances.has(neighbor):
				distances[neighbor] = distances[current] + 1
				queue.append(neighbor)
	return distances


static func _assign_item_room_from_distances(layout: Dictionary, distances: Dictionary) -> void:
	var best_pos: Vector2i = Vector2i.ZERO
	var best_dist := -1

	for pos in layout.keys():
		var data: RoomData = layout[pos]
		if data.type != RoomData.Type.NORMAL:  # skips START/BOSS automatically — boss is already reassigned by this point
			continue
		var connections := 0
		for dir in DIRECTIONS:
			if data.doors[dir]:
				connections += 1
		if connections == 1 and distances.get(pos, 0) > best_dist:
			best_dist = distances[pos]
			best_pos = pos

	if best_dist == -1:
		for pos in layout.keys():
			if layout[pos].type == RoomData.Type.NORMAL and distances.get(pos, 0) > best_dist:
				best_dist = distances[pos]
				best_pos = pos

	if layout.has(best_pos):
		layout[best_pos].type = RoomData.Type.ITEM
