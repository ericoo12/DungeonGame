class_name DungeonGenerator
extends RefCounted

const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)
const EAST := Vector2i(1, 0)
const WEST := Vector2i(-1, 0)
const DIRECTIONS := [NORTH, SOUTH, EAST, WEST]

## Shapes a big NORMAL room can roll (map squares wide x tall), picked evenly.
## L_SHAPE = a 2x2 with one random corner square missing.
const L_SHAPE := Vector2i(-2, -2)
const BIG_SHAPES: Array[Vector2i] = [Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2), L_SHAPE]
const L_CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]


## Builds the floor in steps:
##   1. A random tree of START + NORMAL rooms (room_count - 2 of them). Each new normal
##      room has `big_room_chance` to be a big one (BIG_SHAPES: wide, tall, 2x2 or L)
##      covering several map squares. Every pair of neighbouring START/NORMAL rooms gets ONE door, on a random
##      shared edge (a 2x2 room can have up to 8 door spots).
##   2. Special rooms attached as NEW dead ends on an empty square that touches exactly ONE
##      normal room (added last, so nothing else can end up next to them). Always 1x1:
##        - BOSS: farthest spot from the start, one normal door.
##        - ITEM / SHOP: random spot, NO door. The neighbouring normal room gets a
##          clogged PORTAL toilet leading in; the special room gets an (unclogged)
##          toilet leading back. One portal toilet per room.
##   3. chest_chance of the remaining normal rooms get a CHEST toilet.
## Total rooms = room_count + 1 (the shop is extra).
## layout: every map square -> its RoomData (a big room's squares share one RoomData).
## distances: room home_cell() -> steps from the start.
## (_loop_chance / _max_loops: kept for old callers; every neighbouring pair of normal
## rooms is already connected, so there's nothing left to loop.)
static func generate(room_count: int, _loop_chance: float = 0.1, _max_loops: int = 1,
		chest_chance: float = 0.15, challenge_chance: float = 0.0, big_room_chance: float = 0.0) -> Dictionary:
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

	while unique_rooms(layout).size() < normal_target and attempts < max_attempts:
		attempts += 1
		_grow_normal_room(layout, frontier, big_room_chance)

	_assign_doors(layout)

	# Specials as single-door leaves. Boss first so it gets the farthest spot.
	_attach_special_room(layout, frontier, RoomData.Type.BOSS, true)
	_attach_special_room(layout, frontier, RoomData.Type.ITEM, false)
	_attach_special_room(layout, frontier, RoomData.Type.SHOP, false)
	# Challenge room (some floors): a dead end behind its own red door.
	if randf() < challenge_chance:
		_attach_special_room(layout, frontier, RoomData.Type.CHALLENGE, false)

	for data: RoomData in unique_rooms(layout):
		if data.type == RoomData.Type.NORMAL and data.toilet_kind == RoomData.ToiletKind.NONE \
				and randf() < chest_chance:
			data.toilet_kind = RoomData.ToiletKind.CHEST

	var distances: Dictionary = _bfs_distances(layout, start_pos)
	return {"layout": layout, "distances": distances}


## Every RoomData in the layout once (big rooms appear under several squares).
static func unique_rooms(layout: Dictionary) -> Array:
	var seen: Dictionary = {}
	var result: Array = []
	for data in layout.values():
		if not seen.has(data):
			seen[data] = true
			result.append(data)
	return result


## One random step of the tree: a new NORMAL room next to a random frontier square,
## connected to every neighbouring START/NORMAL room. Returns false if the spot was taken.
static func _grow_normal_room(layout: Dictionary, frontier: Array[Vector2i], big_room_chance: float = 0.0) -> bool:
	var from: Vector2i = frontier[randi() % frontier.size()]
	var dir: Vector2i = DIRECTIONS[randi() % DIRECTIONS.size()]
	var next: Vector2i = from + dir
	if layout.has(next):
		return false
	var size := Vector2i.ONE
	var anchor := next
	var missing := RoomData.NO_MISSING_CELL
	if big_room_chance > 0.0 and randf() < big_room_chance:
		var big: Vector2i = BIG_SHAPES[randi() % BIG_SHAPES.size()]
		var big_missing := RoomData.NO_MISSING_CELL
		if big == L_SHAPE:
			big = Vector2i(2, 2)
			big_missing = L_CORNERS[randi() % L_CORNERS.size()]
		# Every placement that covers `next`; take the first one that's completely free.
		var options: Array[Vector2i] = []
		for ox in big.x:
			for oy in big.y:
				if Vector2i(ox, oy) != big_missing:
					options.append(next - Vector2i(ox, oy))
		options.shuffle()
		for a in options:
			if _area_free(layout, a, big, big_missing):
				size = big
				anchor = a
				missing = big_missing
				break
	var data := RoomData.new()
	data.grid_pos = anchor
	data.size = size
	data.missing_cell = missing
	data.type = RoomData.Type.NORMAL
	for d in DIRECTIONS:
		data.doors[d] = false
	for cell in data.cells():
		layout[cell] = data
		frontier.append(cell)
	_connect_to_neighbours(layout, data)
	return true


static func _area_free(layout: Dictionary, anchor: Vector2i, size: Vector2i,
		missing: Vector2i = RoomData.NO_MISSING_CELL) -> bool:
	for x in size.x:
		for y in size.y:
			if Vector2i(x, y) != missing and layout.has(anchor + Vector2i(x, y)):
				return false
	return true


## Gives `data` one door to each neighbouring START/NORMAL room it isn't connected to yet,
## on a random edge they share.
static func _connect_to_neighbours(layout: Dictionary, data: RoomData) -> void:
	if not _is_plain(data):
		return
	var shared: Dictionary = {}  # neighbour RoomData -> [[cell, dir], ...]
	for cell in data.cells():
		for dir in DIRECTIONS:
			var other: RoomData = layout.get(cell + dir)
			if other == null or other == data or not _is_plain(other):
				continue
			if not shared.has(other):
				shared[other] = []
			shared[other].append([cell, dir])
	for other in shared:
		var edges: Array = shared[other]
		var connected := false
		for e in edges:
			if data.has_door_at(e[0], e[1]):
				connected = true
		if not connected:
			var e: Array = edges[randi() % edges.size()]
			_connect(layout, e[0], e[1])


## Puts a special room on an empty square whose ONLY neighbouring room is a NORMAL room,
## with one door between them (BOSS) or a toilet link (ITEM/SHOP; see generate()). farthest = pick the spot farthest from the start
## (boss), otherwise a random one. If no such square exists (very cramped layout), grows
## one more normal room and tries again.
static func _attach_special_room(layout: Dictionary, frontier: Array[Vector2i],
		type: RoomData.Type, farthest: bool) -> void:
	for _try in 50:
		var distances := _bfs_distances(layout, Vector2i.ZERO)
		var candidates: Array = []  # [cell, parent_cell, dir_from_parent, distance]
		for pos in layout.keys():
			var parent: RoomData = layout[pos]
			if parent.type != RoomData.Type.NORMAL:
				continue
			var via_toilet := type == RoomData.Type.ITEM or type == RoomData.Type.SHOP
			if via_toilet and parent.toilet_kind != RoomData.ToiletKind.NONE:
				continue  # that room already has a toilet to another special room
			for dir in DIRECTIONS:
				var cell: Vector2i = pos + dir
				if layout.has(cell) or _neighbor_count(layout, cell) != 1:
					continue
				candidates.append([cell, pos, dir, distances.get(parent.home_cell(), 0) + 1])

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
		# No automatic fight: the shop has none, the challenge starts when you pay an altar.
		data.cleared = type == RoomData.Type.SHOP or type == RoomData.Type.CHALLENGE
		for d in DIRECTIONS:
			data.doors[d] = false
		layout[pick[0]] = data
		if type == RoomData.Type.ITEM or type == RoomData.Type.SHOP:
			var parent: RoomData = layout[pick[1]]
			parent.toilet_kind = RoomData.ToiletKind.PORTAL
			parent.toilet_target = pick[0]
			data.toilet_kind = RoomData.ToiletKind.PORTAL
			data.toilet_target = pick[1]  # the square next to it (always part of the room)
			data.toilet_unclogged = true  # the way back out is always open
		else:
			_connect(layout, pick[1], pick[2])
		return
	push_warning("DungeonGenerator: could not place special room %s" % RoomData.Type.keys()[type])


## How many different rooms touch this square.
static func _neighbor_count(layout: Dictionary, cell: Vector2i) -> int:
	var rooms: Dictionary = {}
	for dir in DIRECTIONS:
		if layout.has(cell + dir):
			rooms[layout[cell + dir]] = true
	return rooms.size()


## START/NORMAL: rooms that may freely connect to each other.
static func _is_plain(data: RoomData) -> bool:
	return data.type == RoomData.Type.START or data.type == RoomData.Type.NORMAL


## Every START/NORMAL room gets one door to every START/NORMAL neighbour. Runs before the
## special rooms exist, so they keep their single door.
static func _assign_doors(layout: Dictionary) -> void:
	for data: RoomData in unique_rooms(layout):
		_connect_to_neighbours(layout, data)


## Steps from the start room to every room (through doors and portal toilets), keyed by
## each room's home_cell() (grid_pos isn't unique: a room can sit in an L's notch).
static func _bfs_distances(layout: Dictionary, start_pos: Vector2i) -> Dictionary:
	var start: RoomData = layout[start_pos]
	var distances: Dictionary = {start.home_cell(): 0}
	var queue: Array[RoomData] = [start]
	var head := 0
	while head < queue.size():
		var current: RoomData = queue[head]
		head += 1
		var neighbors: Array[RoomData] = []
		for e in current.door_edges():
			var other: RoomData = layout.get(e[0] + e[1])
			if other:
				neighbors.append(other)
		if current.toilet_kind == RoomData.ToiletKind.PORTAL and layout.has(current.toilet_target):
			neighbors.append(layout[current.toilet_target])  # toilets link rooms too
		for neighbor in neighbors:
			if not distances.has(neighbor.home_cell()):
				distances[neighbor.home_cell()] = distances[current.home_cell()] + 1
				queue.append(neighbor)
	return distances


## Door on `cell`'s `dir` side, and the matching one on the other room's side.
static func _connect(layout: Dictionary, cell: Vector2i, dir: Vector2i) -> void:
	(layout[cell] as RoomData).set_door_at(cell, dir, true)
	(layout[cell + dir] as RoomData).set_door_at(cell + dir, -dir, true)
