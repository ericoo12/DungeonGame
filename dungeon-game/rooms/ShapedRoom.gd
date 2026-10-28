## A big normal room covering several map squares (RoomData.size: 2x1 wide, 1x2 tall,
## 2x2 big, or an L = 2x2 with one corner square missing). Built in code from
## NormalRoom01 when the room loads, square by square:
##   - a wall on every square edge that doesn't lead into another square of the room
##     (so the L's inner corner gets walls too), with a doorway where a door is,
##   - a door per connected edge (copies of NormalRoom01's N/S/E/W doors),
##   - floor art built from the floor variant's room quarter: floor per square, a wall
##     band along every wall, the bolted corner plate on every outer corner,
##   - the L's missing square: solid fill (VOID_TEX) + blocked in the grid,
##   - the L's inner corner: the two wall bands joined with a 45° mitre, plus the
##     floor variant's own inner-corner art if it has one (INNER_CORNER_ART),
##   - NormalRoom01's obstacle markers repeated in every square,
##   - more enemies (enemies_per_extra_square), camera scrolls inside the room.
## The room's centre is the centre of its size box, like every other room.
extends RoomController
class_name ShapedRoom

## Size of one map square in the world (a normal room).
const SQUARE := Vector2(432, 224)
## Half a doorway opening (px).
const DOOR_GAP := 16.0
## Inner-corner art per floor variant texture: [art path, floor corner, band start].
## The art is drawn for the TOP-RIGHT square missing (walls along the bottom and left of
## that quarter, floor transparent). "floor corner" = the art pixel placed where the two
## walls' floor-side edges meet (tuned so the art's pipes line up with the bands').
## Only a 32 px wall-thick L of it is used, mirrored for the other three orientations.
## "band start" = the top band column the horizontal wall run starts with next to the
## art, so the band's pipe picks up right where the art's pipe ends.
## Variants without art get the mitre only.
const INNER_CORNER_ART := {
	"res://assets/sprites/tiles/sewer.png": ["res://assets/sprites/tiles/sewer_inner_corner_rust.png", Vector2(60, 61), 64.0],
}
## Columns of the top band used for the mitre (has the rusty pipe on sewer.png, no drip).
const MITRE_TOP_U := 192.0
## Seamless fill for the L's missing square.
const VOID_TEX := "res://assets/sprites/tiles/sewer_void.png"
const VOID_COLOR := Color(0.07, 0.075, 0.08)

## Parts of the floor variant's room quarter (its top-left corner, see RoomBase.tscn):
## the corner plate, the top wall band and the left wall band (32 px thick).
const Q_CORNER := Rect2(10, 0, 32, 32)
const Q_TOP_BAND := Rect2(42, 0, 170, 32)
const Q_LEFT_BAND := Rect2(10, 32, 32, 80)
const Q_FLOOR := Rect2(80, 48, 64, 48)
const BAND := 32.0

## Extra enemies for each square past the first, as a share of a normal room's count
## (0.5: a 2x1 room gets 1.5x, a 2x2 room 2.5x, an L 2x).
@export var enemies_per_extra_square: float = 0.5

var shape: Vector2i = Vector2i.ONE     # size box in map squares
var anchor: Vector2i = Vector2i.ZERO   # map square of the box's top-left corner
var room_size: Vector2 = SQUARE        # size box in px
var _data: RoomData = null


func setup(room_data: RoomData, distance: int, dungeon: Dungeon, entities_container: Node2D) -> void:
	_data = room_data
	shape = room_data.size
	anchor = room_data.grid_pos
	room_size = Vector2(shape) * SQUARE
	_build_doors(room_data)
	_build_walls()
	_repeat_markers()
	var w := room_size.x / 2.0
	var h := room_size.y / 2.0
	grid_rect = Rect2i(-int(w / 16.0) - 1, -int(h / 16.0) - 1, int(w / 8.0) + 2, int(h / 8.0) + 2)
	$Background.visible = false
	super.setup(room_data, distance, dungeon, entities_container)


# --- Geometry --------------------------------------------------------------------------

## Is the square at `rel` (relative to the box's top-left) part of the room?
func _in(rel: Vector2i) -> bool:
	return _data.has_cell(anchor + rel)


## Centre of map square `cell` (absolute), local to the room.
func square_center_local(cell: Vector2i) -> Vector2:
	var rel := cell - anchor
	return -room_size / 2.0 + SQUARE / 2.0 + Vector2(rel) * SQUARE


## Local rect of the square at `rel`.
func _square_rect(rel: Vector2i) -> Rect2:
	return Rect2(-room_size / 2.0 + Vector2(rel) * SQUARE, SQUARE)


## Every square of the box that isn't part of the room (the L's notch).
func _missing_squares() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in shape.y:
		for x in shape.x:
			if not _in(Vector2i(x, y)):
				result.append(Vector2i(x, y))
	return result


## Camera limits (Dungeon checks for this).
func get_arena_bounds() -> Rect2:
	return Rect2(global_position - room_size / 2.0, room_size)


## The open floor inside the outer walls (the box; an L's notch is walled off, so
## pickups can't get in there anyway).
func get_floor_rect() -> Rect2:
	var w := room_size.x / 2.0
	var h := room_size.y / 2.0
	return Rect2(global_position + Vector2(-w + 37, -h + 29), Vector2(room_size.x - 74, room_size.y - 62))


func get_door_entry_point(cell: Vector2i, dir: Vector2i, dungeon: Dungeon) -> Vector2:
	return to_global(square_center_local(cell)) + dungeon.get_entry_offset(dir)


func _enemy_count_scale() -> float:
	return 1.0 + enemies_per_extra_square * (_data.cells().size() - 1)


## The L's notch is solid: never walkable, nothing spawns or paths there.
func _add_wall_blockers_to_grid() -> void:
	super._add_wall_blockers_to_grid()
	for rel in _missing_squares():
		var r := _square_rect(rel)
		grid.block_rect(Rect2(to_global(r.position), r.size))


# --- Doors -----------------------------------------------------------------------------

## One door per connected edge, copied from the scene's N/S/E/W doors. A template's
## position is relative to a normal room's centre, so it's the same offset from the
## centre of the door's square. `doors` is keyed by RoomData.edge_key here.
func _build_doors(room_data: RoomData) -> void:
	var templates: Dictionary = doors.duplicate()  # direction -> Door (from RoomBase)
	doors.clear()
	for e in room_data.door_edges():
		var cell: Vector2i = e[0]
		var dir: Vector2i = e[1]
		var template: Door = templates.get(dir)
		if template == null:
			continue
		# No signal copies: Door._ready connects its own body_entered.
		var door := template.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION) as Door
		door.name = "%s_%d_%d" % [template.name, cell.x - anchor.x, cell.y - anchor.y]
		door.position = square_center_local(cell) + template.position
		$Doors.add_child(door)
		door.direction = dir
		door.cell = cell
		doors[RoomData.edge_key(cell, dir)] = door
	for t in templates.values():
		t.get_parent().remove_child(t)
		t.queue_free()


func _setup_doors(room_data: RoomData, dungeon: Dungeon) -> void:
	for door: Door in doors.values():
		_setup_door(door, true, room_data, dungeon)


# --- Walls -----------------------------------------------------------------------------

## Every square edge that faces outside the room (or the L's notch) gets RoomBase's wall
## (same thickness/offsets), with a doorway if it has a door, plus a projectile wall.
## Projectile walls stick out 30 px past an edge's end only at outer corners (at the
## L's inner corner they'd poke into the floor).
func _build_walls() -> void:
	var blockers: Node = $WallBlockers
	var shot_walls: Node = $ProjectileWalls
	for parent in [blockers, shot_walls]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	for y in shape.y:
		for x in shape.x:
			var rel := Vector2i(x, y)
			if not _in(rel):
				continue
			var r := _square_rect(rel)
			var cell := anchor + rel
			for dir in DungeonGenerator.DIRECTIONS:
				if _in(rel + dir):
					continue
				var has_door := _data.has_door_at(cell, dir)
				var along: Vector2i = Vector2i(abs(dir.y), abs(dir.x))  # direction along the edge
				var ext_a := 0.0 if _in(rel - along) else 30.0
				var ext_b := 0.0 if _in(rel + along) else 30.0
				match dir:
					DungeonGenerator.NORTH:
						_add_wall_line(blockers, Rect2(r.position.x, r.position.y - 19, r.size.x, 48), true, has_door)
						_add_box(shot_walls, Rect2(r.position.x - ext_a, r.position.y - 38, r.size.x + ext_a + ext_b, 40))
					DungeonGenerator.SOUTH:
						# South edge = bottom - 33, same as RoomBase and the south door's blocker.
						_add_wall_line(blockers, Rect2(r.position.x, r.end.y - 33, r.size.x, 48), true, has_door)
						_add_box(shot_walls, Rect2(r.position.x - ext_a, r.end.y - 16, r.size.x + ext_a + ext_b, 40))
					DungeonGenerator.WEST:
						_add_wall_line(blockers, Rect2(r.position.x - 8, r.position.y, 45, r.size.y), false, has_door)
						_add_box(shot_walls, Rect2(r.position.x - 20, r.position.y - ext_a, 40, r.size.y + ext_a + ext_b))
					DungeonGenerator.EAST:
						_add_wall_line(blockers, Rect2(r.end.x - 37, r.position.y, 45, r.size.y), false, has_door)
						_add_box(shot_walls, Rect2(r.end.x - 20, r.position.y - ext_a, 40, r.size.y + ext_a + ext_b))


## A wall box along one square edge, split around a DOOR_GAP doorway in the middle.
func _add_wall_line(parent: Node, rect: Rect2, horizontal: bool, doorway: bool) -> void:
	if not doorway:
		_add_box(parent, rect)
		return
	if horizontal:
		var mid := rect.get_center().x
		_add_box(parent, Rect2(rect.position.x, rect.position.y, mid - DOOR_GAP - rect.position.x, rect.size.y))
		_add_box(parent, Rect2(mid + DOOR_GAP, rect.position.y, rect.end.x - mid - DOOR_GAP, rect.size.y))
	else:
		var mid := rect.get_center().y
		_add_box(parent, Rect2(rect.position.x, rect.position.y, rect.size.x, mid - DOOR_GAP - rect.position.y))
		_add_box(parent, Rect2(rect.position.x, mid + DOOR_GAP, rect.size.x, rect.end.y - mid - DOOR_GAP))


func _add_box(parent: Node, rect: Rect2) -> void:
	var cs := CollisionShape2D.new()
	parent.add_child(cs)
	_set_box(cs, rect)


static func _set_box(node: CollisionShape2D, rect: Rect2) -> void:
	var box := RectangleShape2D.new()
	box.size = rect.size
	node.shape = box
	node.position = rect.get_center()
	node.scale = Vector2.ONE


# --- Markers ---------------------------------------------------------------------------

## NormalRoom01's obstacle (and enemy) markers, repeated in every square of the room.
func _repeat_markers() -> void:
	for group in ["obstacle_spawn_points", "enemy_spawn_points"]:
		var originals := _local_group_nodes(group)
		for m: Node2D in originals:
			var parent := m.get_parent()
			for cell in _data.cells():
				var copy := Marker2D.new()
				copy.position = m.position + square_center_local(cell)
				copy.add_to_group(group)
				parent.add_child(copy)
			parent.remove_child(m)
			m.queue_free()


# --- Floor art -------------------------------------------------------------------------

## Built from the floor variant's room quarter (the top-left corner of a room):
## floor per square, the notch fill, a wall band along every wall run, the corner plate
## on every outer corner, and the inner-corner art on the L's inner corner.
func _apply_floor_variant(variant: RoomFloorVariant) -> void:
	var tex: Texture2D = variant.texture if variant and variant.texture else load("res://assets/sprites/tiles/sewer.png")
	var art := Node2D.new()
	art.name = "RoomArt"
	art.z_index = -2
	add_child(art)
	move_child(art, 0)

	for y in shape.y:
		for x in shape.x:
			var rel := Vector2i(x, y)
			var r := _square_rect(rel)
			if _in(rel):
				art.add_child(_tiled(tex, Q_FLOOR, r.position, r.size))
			else:
				art.add_child(_void_fill(r))

	var inner_art: Array = INNER_CORNER_ART.get(tex.resource_path, [])
	var inner_tex: Texture2D = load(inner_art[0]) if not inner_art.is_empty() and ResourceLoader.exists(inner_art[0]) else null
	_add_wall_bands(art, tex, inner_art[2] if inner_tex else Q_TOP_BAND.position.x)

	# Corner points of the squares: 1 room square around it = outer corner plate,
	# 3 = the L's inner corner.
	for j in shape.y + 1:
		for i in shape.x + 1:
			var p := -room_size / 2.0 + Vector2(i, j) * SQUARE
			var around := {Vector2i(-1, -1): _in(Vector2i(i - 1, j - 1)), Vector2i(1, -1): _in(Vector2i(i, j - 1)),
				Vector2i(-1, 1): _in(Vector2i(i - 1, j)), Vector2i(1, 1): _in(Vector2i(i, j))}
			var inside: Array = around.keys().filter(func(k): return around[k])
			if inside.size() == 1:
				var d: Vector2i = inside[0]
				art.add_child(_mirrored(tex, Q_CORNER, p, Vector2(d)))
			elif inside.size() == 3:
				var out: Vector2i = around.keys().filter(func(k): return not around[k])[0]
				art.add_child(_inner_corner(tex, p, out, inner_tex, inner_art[1] if inner_tex else Vector2.ZERO))


## Is lattice point (i, j) (a corner of the squares) the L's inner corner?
func _concave_at(i: int, j: int) -> bool:
	var n := 0
	for o in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		if _in(Vector2i(i, j) + o):
			n += 1
	return n == 3


## One band per straight run of wall (so the tiling doesn't restart at every square).
## A horizontal run that touches the L's inner corner is tiled FROM that corner (mirrored
## if the corner is at its right end), starting at top band column `inner_band_u`.
func _add_wall_bands(art: Node, tex: Texture2D, inner_band_u: float) -> void:
	for dir in DungeonGenerator.DIRECTIONS:
		var horizontal: bool = dir.y != 0
		var lines: int = shape.y if horizontal else shape.x
		var steps: int = shape.x if horizontal else shape.y
		for line in lines:
			var run_start := -1
			for k in steps + 1:
				var rel := Vector2i(k, line) if horizontal else Vector2i(line, k)
				var wall := k < steps and _in(rel) and not _in(rel + dir)
				if wall and run_start < 0:
					run_start = k
				elif not wall and run_start >= 0:
					var first := Vector2i(run_start, line) if horizontal else Vector2i(line, run_start)
					var r := _square_rect(first)
					var length := (k - run_start) * (SQUARE.x if horizontal else SQUARE.y)
					var holder := Node2D.new()
					match dir:
						DungeonGenerator.NORTH: holder.position = r.position
						DungeonGenerator.SOUTH: holder.position = Vector2(r.position.x, r.end.y)
						DungeonGenerator.WEST: holder.position = r.position
						DungeonGenerator.EAST: holder.position = Vector2(r.end.x, r.position.y)
					holder.scale = Vector2(-1 if dir == DungeonGenerator.EAST else 1, -1 if dir == DungeonGenerator.SOUTH else 1)
					var edge_j := line + (1 if dir == DungeonGenerator.SOUTH else 0)
					if horizontal and (_concave_at(run_start, edge_j) or _concave_at(k, edge_j)):
						var band := Rect2(inner_band_u, 0, Q_TOP_BAND.end.x - inner_band_u, BAND)
						if not _concave_at(run_start, edge_j):
							holder.position.x += length  # tile from the right end, mirrored
							holder.scale.x = -1
						holder.add_child(_tiled(tex, band, Vector2.ZERO, Vector2(length, BAND)))
					elif horizontal:
						holder.add_child(_tiled(tex, Q_TOP_BAND, Vector2.ZERO, Vector2(length, BAND)))
					else:
						holder.add_child(_tiled(tex, Q_LEFT_BAND, Vector2.ZERO, Vector2(BAND, length)))
					art.add_child(holder)
					run_start = -1


## The L's inner corner at point `p` (the corner of the missing square `out` points to).
## Built for the top-right missing and mirrored. The two wall bands stop at the missing
## square's edges, leaving a 32x32 gap on the floor side of the corner: it's filled with
## both bands meeting on a 45° line (a mitre). Then the variant's own art, if any.
func _inner_corner(tex: Texture2D, p: Vector2, out: Vector2i, inner_tex: Texture2D, floor_corner: Vector2) -> Node2D:
	var holder := Node2D.new()
	holder.position = p
	holder.scale = Vector2(out.x, -out.y)
	# Below the diagonal: the bottom wall (top band, its row = depth below the corner).
	var bottom := Polygon2D.new()
	bottom.texture = tex
	bottom.polygon = PackedVector2Array([Vector2(0, 0), Vector2(0, BAND), Vector2(-BAND, BAND)])
	bottom.uv = PackedVector2Array([Vector2(MITRE_TOP_U, 0), Vector2(MITRE_TOP_U, BAND), Vector2(MITRE_TOP_U - BAND, BAND)])
	holder.add_child(bottom)
	# Above it: the left wall (left band mirrored, its column = depth left of the corner).
	var side := Polygon2D.new()
	side.texture = tex
	side.polygon = PackedVector2Array([Vector2(0, 0), Vector2(-BAND, 0), Vector2(-BAND, BAND)])
	var u0 := Q_LEFT_BAND.position.x
	var v0 := Q_LEFT_BAND.position.y + 16.0
	side.uv = PackedVector2Array([Vector2(u0, v0), Vector2(u0 + BAND, v0), Vector2(u0 + BAND, v0 + BAND)])
	holder.add_child(side)
	if inner_tex:
		var fc := floor_corner
		# Vertical wall part (incl. the elbow), then the horizontal part to its right.
		holder.add_child(_region_sprite(inner_tex, Rect2(fc.x, 0, BAND, fc.y), Vector2(-BAND, BAND - fc.y)))
		holder.add_child(_region_sprite(inner_tex, Rect2(fc.x + BAND, fc.y - BAND, inner_tex.get_width() - fc.x - BAND, BAND), Vector2.ZERO))
	return holder


func _region_sprite(tex: Texture2D, region: Rect2, pos: Vector2) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.region_enabled = true
	spr.region_rect = region
	spr.position = pos
	return spr


func _tiled(tex: Texture2D, region: Rect2, pos: Vector2, size: Vector2) -> TextureRect:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = region
	var tr := TextureRect.new()
	tr.texture = at
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.position = pos
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## `region` (drawn as the top-left corner) at `p`, mirrored towards `dir` (+1/-1 per axis).
func _mirrored(tex: Texture2D, region: Rect2, p: Vector2, dir: Vector2) -> Node2D:
	var holder := Node2D.new()
	holder.position = p
	holder.scale = dir
	holder.add_child(_tiled(tex, region, Vector2.ZERO, region.size))
	return holder


func _void_fill(r: Rect2) -> Control:
	if ResourceLoader.exists(VOID_TEX):
		var tr := TextureRect.new()
		tr.texture = load(VOID_TEX)
		tr.stretch_mode = TextureRect.STRETCH_TILE
		tr.position = r.position
		tr.size = r.size
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var fill := ColorRect.new()
	fill.color = VOID_COLOR
	fill.position = r.position
	fill.size = r.size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return fill
