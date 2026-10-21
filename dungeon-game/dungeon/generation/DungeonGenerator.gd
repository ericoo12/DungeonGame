class_name DungeonGenerator
extends RefCounted

const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)
const EAST := Vector2i(1, 0)
const WEST := Vector2i(-1, 0)
const DIRECTIONS := [NORTH, SOUTH, EAST, WEST]


## Builds the floor in steps:
##   1. A random tree of START + NORMAL rooms (room_count - 2 of them), doors + loops.
##   2. Special rooms attached as NEW dead ends on an empty cell that touches exactly ONE
##      normal room (added last, so nothing else can end up next to them):
##        - BOSS: farthest spot from the start, one normal door.
##        - ITEM / SHOP: random spot, NO door. The neighbouring normal room gets a
##          clogged PORTAL toilet leading in; the special room gets an (unclogged)
##          toilet leading back. One portal toilet per room.
##   3. chest_chance of the remaining normal rooms get a CHEST toilet.
## Total rooms = room_count + 1 (the shop is extra).
static func generate(room_count: int, loop_chance: float = 0.1, max_loops: int = 1,
		chest_chance: float = 0.15) -> Dictionary:
	var layout: Dictionary = {}
	var start_pos := Vector2i.ZERO

	var start_data := RoomData.new()
	start_data.grid_pos = start_pos
	start_data.type = RoomData.Type.START
	start_data.cleared = true
	for d in DIRECTIONS:
		start_data.doors[d] = false
	layout[start_pos] = start_data

	var normal_target := maxi(room_count - 2, 2)  # start + at least one normal room
	var frontier: Array[Vector2i] = [start_pos]
	var attempts := 0
	var max_attempts := normal_target * 20

	while layout.size() < normal_target and attempts < max_attempts:
		attempts += 1
		_grow_normal_room(layout, frontier)

	_assign_doors(layout)
	_assign_extra_connections(layout, loop_chance, max_loops)

	# Specials as single-door leaves. Boss first so it gets the farthest spot.
	_attach_special_room(layout, frontier, RoomData.Type.BOSS, true)
	_attach_special_room(layout, frontier, RoomData.Type.ITEM, false)
	_attach_special_room(layout, frontier, RoomData.Type.SHOP, false)

	for pos in layout.keys():
		var data: RoomData = layout[pos]
		if data.type == RoomData.Type.NORMAL and data.toilet_kind == RoomData.ToiletKind.NONE \
				and randf() < chest_chance:
			data.toilet_kind = RoomData.ToiletKind.CHEST

	var distances: Dictionary = _bfs_distances(layout, start_pos)
	return {"layout": layout, "distances": distances}


## One random step of the tree: a new NORMAL room next to a random frontier room.
## Returns false if the picked spot was taken.
static func _grow_normal_room(layout: Dictionary, frontier: Array[Vector2i]) -> bool:
	var from: Vector2i = frontier[randi() % frontier.size()]
	var dir: Vector2i = DIRECTIONS[randi() % DIRECTIONS.size()]
	var next: Vector2i = from + dir
	if layout.has(next):
		return false
	var data := RoomData.new()
	data.grid_pos = next
	data.type = RoomData.Type.NORMAL
	for d in DIRECTIONS:
		data.doors[d] = false
	layout[next] = data
	frontier.append(next)
	_connect(layout, from, next, dir)
	# Same rule as _assign_doors(): normal rooms connect to every normal neighbour.
	for d in DIRECTIONS:
		var other: Vector2i = next + d
		if layout.has(other) and _is_plain(layout[other]):
			_connect(layout, next, other, d)
	return true


## Puts a special room on an empty cell whose ONLY neighbouring room is a NORMAL room,
## with one door between them (BOSS) or a toilet link (ITEM/SHOP; see generate()). farthest = pick the spot farthest from the start
## (boss), otherwise a random one. If no such cell exists (very cramped layout), grows
## one more normal room and tries again.
static func _attach_special_room(layout: Dictionary, frontier: Array[Vector2i],
		type: RoomData.Type, farthest: bool) -> void:
	for _try in 50:
		var distances := _bfs_distances(layout, Vector2i.ZERO)
		var candidates: Array = []  # [cell, parent, dir_from_parent, distance]
		for pos in layout.keys():
			if layout[pos].type != RoomData.Type.NORMAL:
				continue
			var via_toilet := type == RoomData.Type.ITEM or type == RoomData.Type.SHOP
			if via_toilet and layout[pos].toilet_kind != RoomData.ToiletKind.NONE:
				continue  # that room already has a toilet to another special room
			for dir in DIRECTIONS:
				var cell: Vector2i = pos + dir
				if layout.has(cell) or _neighbor_count(layout, cell) != 1:
					continue
				candidates.append([cell, pos, dir, distances.get(pos, 0) + 1])

		if candidates.is_empty():
			_grow_normal_room(layout, frontier)
			continue

		var pick: Array = candidates[randi() % candidates.size()]
		if farthest:
			for c in candidates:
				if c[3] > pick[3]:
					pick = c

		var data := RoomData.new()
		data.grid_pos = pick[0]
		data.type = type
		data.cleared = type == RoomData.Type.SHOP  # no fight in the shop
		for d in DIRECTIONS:
			data.doors[d] = false
		layout[pick[0]] = data
		if type == RoomData.Type.ITEM or type == RoomData.Type.SHOP:
			var parent: RoomData = layout[pick[1]]
			parent.toilet_kind = RoomData.ToiletKind.PORTAL
			parent.toilet_target = pick[0]
			data.toilet_kind = RoomData.ToiletKind.PORTAL
			data.toilet_target = pick[1]
			data.toilet_unclogged = true  # the way back out is always open
		else:
			_connect(layout, pick[1], pick[0], pick[2])
		return
	push_warning("DungeonGenerator: could not place special room %s" % RoomData.Type.keys()[type])


static func _neighbor_count(layout: Dictionary, cell: Vector2i) -> int:
	var n := 0
	for dir in DIRECTIONS:
		if layout.has(cell + dir):
			n += 1
	return n


## START/NORMAL: rooms that may freely connect to each other.
static func _is_plain(data: RoomData) -> bool:
	return data.type == RoomData.Type.START or data.type == RoomData.Type.NORMAL


## Every START/NORMAL room gets a door to every START/NORMAL neighbour. Runs before the
## special rooms exist, so they keep their single door.
static func _assign_doors(layout: Dictionary) -> void:
	for pos in layout.keys():
		var data: RoomData = layout[pos]
		for dir in DIRECTIONS:
			var other: RoomData = layout.get(pos + dir)
			data.doors[dir] = other != null and _is_plain(data) and _is_plain(other)


static func _bfs_distances(layout: Dictionary, start_pos: Vector2i) -> Dictionary:
	var distances: Dictionary = {start_pos: 0}
	var queue: Array[Vector2i] = [start_pos]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var current_data: RoomData = layout[current]
		var neighbors: Array[Vector2i] = []
		for dir in DIRECTIONS:
			if current_data.doors[dir]:
				neighbors.append(current + dir)
		if current_data.toilet_kind == RoomData.ToiletKind.PORTAL:
			neighbors.append(current_data.toilet_target)  # toilets link rooms too
		for neighbor in neighbors:
			if not distances.has(neighbor):
				distances[neighbor] = distances[current] + 1
				queue.append(neighbor)
	return distances


static func _connect(layout: Dictionary, a: Vector2i, b: Vector2i, dir: Vector2i) -> void:
	layout[a].doors[dir] = true
	layout[b].doors[-dir] = true  # b sees a in the opposite direction


static func _assign_extra_connections(layout: Dictionary, loop_chance: float, max_loops: int) -> void:
	var loops_added := 0
	for pos in layout.keys():
		if loops_added >= max_loops:
			break
		var data: RoomData = layout[pos]
		for dir in DIRECTIONS:
			if data.doors[dir]:
				continue  # already connected this direction, part of the tree
			var neighbor_pos: Vector2i = pos + dir
			if not layout.has(neighbor_pos):
				continue
			if randf() < loop_chance:
				_connect(layout, pos, neighbor_pos, dir)
				loops_added += 1
				if loops_added >= max_loops:
					break
