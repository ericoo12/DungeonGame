## The minimap, top-right corner. Shows only what you've found:
##   - rooms you've been in: yellow (the room you're in is brighter, with a white frame),
##   - rooms a door leads to from those: grey (you know they're there, not what's inside),
##   - special rooms get a small marker in their colour once discovered (boss, item, shop,
##     challenge).
## Big / L rooms are drawn as one shape. The map scales to the whole floor's size, so it
## always fits in MAX_SIZE however many rooms later stages have.
## `reveal_all` (set from code / the debugger) shows every room, for testing.
extends Control

static var reveal_all: bool = false

## Largest the map may get on screen, and its distance from the top-right corner.
const MAX_SIZE := Vector2(230, 140)
const CORNER_MARGIN := Vector2(10, 10)
const MAX_CELL := 24.0
const MIN_CELL := 8.0
const GAP := 2.0                 # between rooms

const COL_VISITED := Color(0.92, 0.76, 0.28)
const COL_CURRENT := Color(1.0, 0.96, 0.72)
const COL_UNKNOWN := Color(0.42, 0.42, 0.45, 0.9)
const COL_FRAME := Color(1, 1, 1)
const MARKERS := {
	RoomData.Type.BOSS: Color(0.9, 0.2, 0.2),
	RoomData.Type.ITEM: Color(1.0, 0.9, 0.3),
	RoomData.Type.SHOP: Color(0.3, 0.85, 0.4),
	RoomData.Type.CHALLENGE: Color(0.7, 0.3, 0.9),
}
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var dungeon: Dungeon


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_find_dungeon")


func _find_dungeon() -> void:
	dungeon = get_tree().get_first_node_in_group("dungeon")


func _process(_delta: float) -> void:
	if is_instance_valid(dungeon):
		queue_redraw()


## Rooms to draw: visited ones + the ones their doors lead to (or all with reveal_all).
func _shown_rooms() -> Dictionary:
	var shown := {}
	var rooms := DungeonGenerator.unique_rooms(dungeon.layout)
	for data: RoomData in rooms:
		if reveal_all or data.visited:
			shown[data] = true
	if reveal_all:
		return shown
	for data: RoomData in shown.keys():
		for cell in data.cells():
			for dir in DIRS:
				if data.has_door_at(cell, dir):
					var next: RoomData = dungeon.layout.get(cell + dir)
					if next:
						shown[next] = true
	return shown


func _draw() -> void:
	if not is_instance_valid(dungeon) or dungeon.layout.is_empty():
		return
	# Size from the whole floor (not just what's found), so the map doesn't jump around
	# while you explore.
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := -lo
	for cell: Vector2i in dungeon.layout:
		lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
		hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
	var cells := Vector2(hi - lo + Vector2i.ONE)
	var cs := clampf(minf(MAX_SIZE.x / cells.x, MAX_SIZE.y / cells.y), MIN_CELL, MAX_CELL)
	var map_size := cells * cs
	var origin := Vector2(size.x - CORNER_MARGIN.x - map_size.x, CORNER_MARGIN.y)

	var shown := _shown_rooms()
	if shown.is_empty():
		return

	var current: RoomData = dungeon.layout.get(dungeon.current_grid_pos)
	var gap := minf(GAP, cs * 0.2)
	for data: RoomData in shown:
		var col := COL_UNKNOWN
		if data == current:
			col = COL_CURRENT
		elif data.visited:
			col = COL_VISITED
		for cell in data.cells():
			draw_rect(_cell_rect(data, cell, origin, lo, cs, gap), col)
		if data == current:
			for cell in data.cells():
				_draw_frame(data, cell, _cell_rect(data, cell, origin, lo, cs, gap))
		if MARKERS.has(data.type):
			var c := _cell_rect(data, data.home_cell(), origin, lo, cs, gap).get_center()
			var r := maxf(cs * 0.2, 1.5)
			draw_circle(c, r + 1.0, Color(0, 0, 0, 0.6))
			draw_circle(c, r, MARKERS[data.type])


## One map square of a room. Edges towards another square of the same room aren't inset,
## so big / L rooms come out as one shape.
func _cell_rect(data: RoomData, cell: Vector2i, origin: Vector2, lo: Vector2i, cs: float, gap: float) -> Rect2:
	var r := Rect2(origin + Vector2(cell - lo) * cs, Vector2.ONE * cs)
	var h := gap / 2.0
	var left := 0.0 if data.has_cell(cell + Vector2i.LEFT) else h
	var right := 0.0 if data.has_cell(cell + Vector2i.RIGHT) else h
	var top := 0.0 if data.has_cell(cell + Vector2i.UP) else h
	var bottom := 0.0 if data.has_cell(cell + Vector2i.DOWN) else h
	return Rect2(r.position + Vector2(left, top), r.size - Vector2(left + right, top + bottom))


## White outline of the current room: only the sides on the room's outer edge.
func _draw_frame(data: RoomData, cell: Vector2i, r: Rect2) -> void:
	var w := 1.5
	if not data.has_cell(cell + Vector2i.UP):
		draw_line(r.position, Vector2(r.end.x, r.position.y), COL_FRAME, w)
	if not data.has_cell(cell + Vector2i.DOWN):
		draw_line(Vector2(r.position.x, r.end.y), r.end, COL_FRAME, w)
	if not data.has_cell(cell + Vector2i.LEFT):
		draw_line(r.position, Vector2(r.position.x, r.end.y), COL_FRAME, w)
	if not data.has_cell(cell + Vector2i.RIGHT):
		draw_line(Vector2(r.end.x, r.position.y), r.end, COL_FRAME, w)
