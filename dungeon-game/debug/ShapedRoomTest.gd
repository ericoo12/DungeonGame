## Shaped room test: look at every big room shape (wide, tall, 2x2 and the four L's)
## on every floor variant, without playing through a floor. Run debug/ShapedRoomTest.tscn
## with F6.
##
##   Q / E     previous / next shape
##   V         next floor variant (rust / grey / green)
##   F5        zoom out to see the whole room / back
##   N         rooms with / without enemies (reloads the room)
##   F4        hide / show this help
##
## Every shape has a small room on each free side, so all its doors show (an L also has
## one in its notch, for the doors on the inner walls). Walk through a door and back to
## see where you come out. Rooms are cleared (no enemies) unless you press N.
extends Node2D

## [name, size, missing square] - see RoomData.size / missing_cell.
const SHAPES := [
	["Wide 2x1", Vector2i(2, 1), Vector2i(-1, -1)],
	["Tall 1x2", Vector2i(1, 2), Vector2i(-1, -1)],
	["Big 2x2", Vector2i(2, 2), Vector2i(-1, -1)],
	["L (top-right missing)", Vector2i(2, 2), Vector2i(1, 0)],
	["L (top-left missing)", Vector2i(2, 2), Vector2i(0, 0)],
	["L (bottom-right missing)", Vector2i(2, 2), Vector2i(1, 1)],
	["L (bottom-left missing)", Vector2i(2, 2), Vector2i(0, 1)],
]
## Map squares between two shapes in the test layout.
const SPACING := 10

@export var with_enemies: bool = false

@onready var dungeon: Dungeon = $Dungeon
var _shape_rooms: Array[RoomData] = []
var _shape_index: int = 0
var _variant_index: int = 0
var _variants: Array[RoomFloorVariant] = []
var _zoomed_out: bool = false
var _help: Label


func _ready() -> void:
	for v in dungeon.floor_variants:
		if v:
			_variants.append(v)
	_build_help()
	await get_tree().process_frame  # the Dungeon has generated its normal floor by now
	_build_layout()
	_show_shape(0)


## One showcase per shape, each surrounded by 1x1 rooms (they get the doors).
func _build_layout() -> void:
	for e in dungeon.entities.get_children():
		if e is EnemyBase:
			e.queue_free()
	var layout: Dictionary = {}
	_shape_rooms.clear()
	for i in SHAPES.size():
		var data := RoomData.new()
		data.grid_pos = Vector2i(i * SPACING, 0)
		data.size = SHAPES[i][1]
		data.missing_cell = SHAPES[i][2]
		data.type = RoomData.Type.NORMAL
		for d in DungeonGenerator.DIRECTIONS:
			data.doors[d] = false
		for c in data.cells():
			layout[c] = data
		_shape_rooms.append(data)
		# A small room on every free square next to the shape (incl. an L's notch).
		for c in data.cells():
			for d in DungeonGenerator.DIRECTIONS:
				var n: Vector2i = c + d
				if layout.has(n):
					continue
				var small := RoomData.new()
				small.grid_pos = n
				small.type = RoomData.Type.NORMAL
				for dd in DungeonGenerator.DIRECTIONS:
					small.doors[dd] = false
				layout[n] = small
		# One door between the shape and each small room around it.
		DungeonGenerator._connect_to_neighbours(layout, data)
	for data in DungeonGenerator.unique_rooms(layout):
		data.cleared = not with_enemies
	dungeon.layout = layout
	dungeon.room_distances = {}


func _show_shape(index: int) -> void:
	_shape_index = wrapi(index, 0, SHAPES.size())
	if not _variants.is_empty():
		dungeon.current_floor_variant = _variants[_variant_index]
	var data := _shape_rooms[_shape_index]
	for e in dungeon.entities.get_children():
		if e is EnemyBase:
			e.queue_free()
	dungeon.can_travel = true
	dungeon._load_room(data.home_cell(), Vector2i.ZERO)
	# Start in the middle of the shape's first square.
	var room := dungeon.current_room as ShapedRoom
	if room:
		dungeon.player.global_position = room.to_global(room.square_center_local(data.home_cell()))
	dungeon.player.reset_position_history()
	dungeon.player.reset_followers_position()
	_zoomed_out = false
	_update_help()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_Q:
			_show_shape(_shape_index - 1)
		KEY_E:
			_show_shape(_shape_index + 1)
		KEY_V:
			if not _variants.is_empty():
				_variant_index = (_variant_index + 1) % _variants.size()
			_show_shape(_shape_index)
		KEY_N:
			with_enemies = not with_enemies
			_build_layout()
			_show_shape(_shape_index)
		KEY_F5:
			_toggle_zoom()
		KEY_F4:
			_help.visible = not _help.visible
		_:
			return
	get_viewport().set_input_as_handled()


## Zoomed out: the camera stops following the player and shows the whole room.
func _toggle_zoom() -> void:
	var cam: Camera2D = dungeon.player.camera
	var room := dungeon.current_room
	if room == null or not room.has_method("get_arena_bounds"):
		return
	_zoomed_out = not _zoomed_out
	if _zoomed_out:
		var bounds: Rect2 = room.get_arena_bounds()
		var view := get_viewport().get_visible_rect().size
		var z := minf(view.x / (bounds.size.x + 40.0), view.y / (bounds.size.y + 40.0))
		cam.set_meta("test_zoom", cam.zoom)
		cam.limit_left = -100000
		cam.limit_top = -100000
		cam.limit_right = 100000
		cam.limit_bottom = 100000
		cam.zoom = Vector2(z, z)
		cam.position_smoothing_enabled = false
		cam.top_level = true  # stop following the player
		cam.global_position = bounds.get_center()
	else:
		cam.top_level = false
		cam.position = Vector2.ZERO
		cam.zoom = cam.get_meta("test_zoom", cam.zoom)
		dungeon._apply_room_camera_bounds()
	_update_help()


func _build_help() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_help = Label.new()
	_help.position = Vector2(12, get_viewport().get_visible_rect().size.y - 56)  # bottom-left
	_help.add_theme_color_override("font_outline_color", Color.BLACK)
	_help.add_theme_constant_override("outline_size", 4)
	layer.add_child(_help)


func _update_help() -> void:
	var variant_name := "-"
	if not _variants.is_empty():
		variant_name = _variants[_variant_index].resource_path.get_file().get_basename()
	_help.text = "SHAPE %d/%d: %s   floor: %s   enemies: %s%s\nQ/E shape   V floor   F5 zoom out   N enemies   F4 hide" % [
		_shape_index + 1, SHAPES.size(), SHAPES[_shape_index][0], variant_name,
		"on" if with_enemies else "off", "   (zoomed out)" if _zoomed_out else ""]
