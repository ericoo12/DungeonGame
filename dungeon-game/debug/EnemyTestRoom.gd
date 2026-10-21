## Enemy test room: spawn any enemy on demand to test and tune it.
## Run debug/EnemyTestRoom.tscn with F6.
##
##   Q / E          previous / next enemy (or mouse wheel)
##   Enter          spawn the selected enemy at the spawn marker
##   Right click    spawn the selected enemy at the mouse
##   G              toggle packs (rats etc. spawn with their pack_size)
##   Z / X          stage down / up (scales health + damage of NEW spawns)
##   Backspace      remove all enemies
##   F1             god mode (player can't take damage)
##   F2             heal player to full
##   F3             freeze / unfreeze enemies
##   F4             hide / show this help
##   F5             zoom out to see the whole arena / back
##   O              new random obstacle layout
##   L              back to the default obstacle layout
##   K              remove all obstacles
##
## Enemies are found automatically in enemy_folders (subfolders included), so new
## enemies show up here without editing the scene. extra_enemies adds anything else.
extends Node2D

@export var enemy_folders: PackedStringArray = [
	"res://enemies/regular/",
	"res://enemies/bosses/",
]
@export var extra_enemies: Array[PackedScene] = []
@export var god_mode: bool = false
@export var spawn_packs: bool = false
## Stage the room starts on (GameState.current_stage; affects enemy health/damage).
@export var start_stage: int = 1

@export_group("Obstacles")
## Obstacles are picked from here: unbreakable ones (Rock) build the walls of the
## default layout, breakable ones (Pot, TrashBag) are scattered.
@export var obstacle_folder: String = "res://obstacles/"
## Number of obstacles in a random layout (O).
@export var random_obstacle_count: int = 45
## Breakable obstacles scattered in the default layout.
@export var scattered_breakables: int = 8
@export_group("")

## The arena is 4 normal rooms big. Grid cells (16 px) of its inside plus the wall ring.
const ARENA_GRID := Rect2i(-26, -13, 52, 26)
## Fills the arena's door gaps (its doors are sized for normal rooms).
const DOOR_GAP_FILLS: Array[Rect2] = [
	Rect2(-24, -224, 48, 32), Rect2(-24, 192, 48, 32),
	Rect2(-432, -24, 32, 48), Rect2(400, -24, 32, 48),
]
## Default layout (grid cells): a few walls and pockets to test pathing around.
const DEFAULT_WALLS: Array = [
	[Vector2i(-12, -5), Vector2i(-4, -5)],    # horizontal wall, upper left
	[Vector2i(8, -9), Vector2i(8, 2)],        # vertical wall, middle right
	[Vector2i(-18, 6), Vector2i(-12, 6)],     # L shape, lower left
	[Vector2i(-12, 2), Vector2i(-12, 5)],
	[Vector2i(16, -6), Vector2i(20, -6)],     # U shape (pocket opening down), right
	[Vector2i(16, -5), Vector2i(16, -2)],
	[Vector2i(20, -5), Vector2i(20, -2)],
	[Vector2i(-22, -9), Vector2i(-19, -9)],   # small block, top left corner
	[Vector2i(-22, -8), Vector2i(-19, -8)],
	[Vector2i(2, 8), Vector2i(14, 8)],        # long wall, bottom
]

@onready var room: RoomController = $Room
@onready var entities: Node2D = $Entities
@onready var player: Player = $Entities/Player
@onready var spawn_marker: Marker2D = $SpawnPoint
@onready var info: Label = $UI/Info

var _scenes: Array[PackedScene] = []
var _selected: int = 0
var _frozen: bool = false
var _solid_obstacles: Array[PackedScene] = []
var _breakable_obstacles: Array[PackedScene] = []
var _obstacles: Array[Node] = []
@onready var camera: Camera2D = $Entities/Player/Camera2D


func _ready() -> void:
	GameState.current_stage = start_stage
	_scenes = _find_enemy_scenes()

	# The room normally gets this from Dungeon.setup(). Here we only need its walls
	# grid (pathfinding) and a container for spawn_enemy() (used by spawner enemies).
	room.add_to_group("test_room")
	room._entities_container = entities
	room.grid = RoomGrid.new(room, ARENA_GRID)
	_build_walls()
	_load_obstacle_scenes()
	_build_default_layout()
	# Never let the room think it was cleared (that path needs a real Dungeon).
	room._enemy_count = 1 << 30
	for door in room.doors.values():
		door.set_unlocked(false)
	_update_info()


func _process(_delta: float) -> void:
	if god_mode and is_instance_valid(player):
		player.invulnerable = true
	_update_info()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				_spawn_selected(get_global_mouse_position())
			MOUSE_BUTTON_WHEEL_UP:
				_select(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_select(1)
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_Q:
			_select(-1)
		KEY_E:
			_select(1)
		KEY_ENTER, KEY_KP_ENTER:
			_spawn_selected(spawn_marker.global_position)
		KEY_G:
			spawn_packs = not spawn_packs
		KEY_Z:
			GameState.current_stage = maxi(1, GameState.current_stage - 1)
		KEY_X:
			GameState.current_stage += 1
		KEY_BACKSPACE:
			_clear_enemies()
		KEY_F1:
			god_mode = not god_mode
			if not god_mode and is_instance_valid(player):
				player.invulnerable = false
		KEY_F2:
			if is_instance_valid(player):
				player.heal(player.max_hearts)
		KEY_F3:
			_set_frozen(not _frozen)
		KEY_F4:
			info.visible = not info.visible
		KEY_F5:
			camera.zoom = Vector2.ONE * (1.5 if camera.zoom.x > 2.0 else 3.0)
		KEY_O:
			_build_random_layout()
		KEY_L:
			_build_default_layout()
		KEY_K:
			_clear_obstacles()
		_:
			return
	get_viewport().set_input_as_handled()


func _select(step: int) -> void:
	if _scenes.is_empty():
		return
	_selected = posmod(_selected + step, _scenes.size())


func _spawn_selected(pos: Vector2) -> void:
	if _scenes.is_empty():
		return
	var scene := _scenes[_selected]
	var leader := room.spawn_enemy(scene, pos)
	if leader == null:
		return
	if _frozen:
		leader.process_mode = Node.PROCESS_MODE_DISABLED
	if spawn_packs:
		var extra := room._pack_extra_count(leader)
		var member_scene: PackedScene = scene
		if leader is EnemyBase and (leader as EnemyBase).pack_member_scene:
			member_scene = (leader as EnemyBase).pack_member_scene
		for p in room._pack_positions(pos, extra):
			var member := room.spawn_enemy(member_scene, p)
			if member and _frozen:
				member.process_mode = Node.PROCESS_MODE_DISABLED


func _clear_enemies() -> void:
	for child in entities.get_children():
		if child is EnemyBase:
			child.queue_free()
	for shot in get_tree().get_nodes_in_group("projectiles"):
		if shot is EnemyProjectile:
			shot.queue_free()


func _set_frozen(value: bool) -> void:
	_frozen = value
	for child in entities.get_children():
		if child is EnemyBase:
			child.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT


func _enemy_count() -> int:
	var count := 0
	for child in entities.get_children():
		if child is EnemyBase and not child.is_queued_for_deletion():
			count += 1
	return count


func _update_info() -> void:
	if not info.visible:
		return
	var lines := PackedStringArray()
	lines.append("ENEMY TEST ROOM   (F4 hides this)")
	lines.append("Q/E or wheel: select   Enter spawn   Right click spawn at mouse   Backspace clear")
	lines.append("G packs: %s   Z/X stage: %d   F1 god: %s   F2 heal   F3 freeze: %s" % [
		"on" if spawn_packs else "off", GameState.current_stage,
		"on" if god_mode else "off", "on" if _frozen else "off"])
	lines.append("F5 zoom   O random obstacles   L default obstacles   K no obstacles")
	lines.append("Enemies alive: %d" % _enemy_count())
	lines.append("")
	for i in _scenes.size():
		var name := _scenes[i].resource_path.get_file().get_basename()
		lines.append(("> " if i == _selected else "   ") + name)
	info.text = "\n".join(lines)


func _find_enemy_scenes() -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var paths: Array[String] = []
	for folder in enemy_folders:  # folder order kept, sorted within each folder
		var found: Array[String] = []
		_collect_scene_paths(folder, found)
		found.sort()
		paths.append_array(found)
	for path in paths:
		var scene := load(path) as PackedScene
		if scene and _is_enemy(scene):
			result.append(scene)
	for scene in extra_enemies:
		if scene and not result.has(scene):
			result.append(scene)
	return result


func _collect_scene_paths(folder: String, out: Array[String]) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for file in dir.get_files():
		if file.ends_with(".tscn"):
			out.append(folder.path_join(file))
	for sub in dir.get_directories():
		_collect_scene_paths(folder.path_join(sub), out)


## Only scenes whose root runs EnemyBase (skips projectiles etc. kept in the same folders).
static func _is_enemy(scene: PackedScene) -> bool:
	var state := scene.get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == "script":
			var script := state.get_node_property_value(0, i) as Script
			while script:
				if script.get_global_name() == &"EnemyBase":
					return true
				script = script.get_base_script()
	# Inherited scenes (e.g. Rat from EnemyBase.tscn) keep the script on the base scene.
	var base := state.get_node_instance(0)
	return base != null and _is_enemy(base)


# --- Arena walls + obstacles -------------------------------------------------

## The arena's Perimeter walls go into the pathfinding grid, and its door gaps get
## filled (the doors there are normal-room sized and leave holes at the sides).
func _build_walls() -> void:
	var fills := StaticBody2D.new()
	fills.name = "DoorGapFills"
	fills.collision_layer = 1 | (1 << 3)  # world + projectile walls
	fills.collision_mask = 0
	fills.add_to_group("walls")
	room.add_child(fills)
	for r in DOOR_GAP_FILLS:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		fills.add_child(shape)
	for body in [room.get_node_or_null("Perimeter"), fills]:
		if body == null:
			continue
		for child in body.get_children():
			var shape_node := child as CollisionShape2D
			if shape_node == null or not (shape_node.shape is RectangleShape2D):
				continue
			var size: Vector2 = (shape_node.shape as RectangleShape2D).size * shape_node.global_scale.abs()
			room.grid.block_rect(Rect2(shape_node.global_position - size / 2.0, size))


func _load_obstacle_scenes() -> void:
	var dir := DirAccess.open(obstacle_folder)
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		var scene := load(obstacle_folder.path_join(file)) as PackedScene
		var probe := scene.instantiate() if scene else null
		if probe is Obstacle:
			if (probe as Obstacle).breakable:
				_breakable_obstacles.append(scene)
			else:
				_solid_obstacles.append(scene)
		if probe:
			probe.free()


func _build_default_layout() -> void:
	_clear_obstacles()
	for segment in DEFAULT_WALLS:
		var a: Vector2i = segment[0]
		var b: Vector2i = segment[1]
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
				_place_obstacle(Vector2i(x, y), true)
	_scatter(scattered_breakables, false)
	room.obstacle_layout_changed.emit()


func _build_random_layout() -> void:
	_clear_obstacles()
	_scatter(random_obstacle_count, randf() < 0.5)
	room.obstacle_layout_changed.emit()


## `count` obstacles on random free cells (mix of solid and breakable unless only_solid).
func _scatter(count: int, mostly_solid: bool) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 20:
		tries += 1
		var cell := Vector2i(randi_range(ARENA_GRID.position.x + 2, ARENA_GRID.end.x - 3),
			randi_range(ARENA_GRID.position.y + 2, ARENA_GRID.end.y - 3))
		var solid := randf() < (0.8 if mostly_solid else 0.5)
		if _place_obstacle(cell, solid):
			placed += 1


## Places one obstacle on `cell` unless it's taken or too close to the player / spawn.
func _place_obstacle(cell: Vector2i, solid: bool) -> bool:
	var grid := room.grid
	if not grid.is_walkable(cell):
		return false
	for keep_clear in [spawn_marker.global_position, player.global_position]:
		if grid.global_to_cell(keep_clear).distance_to(cell) < 2.5:
			return false
	var pool := _solid_obstacles if solid and not _solid_obstacles.is_empty() else _breakable_obstacles
	if pool.is_empty():
		return false
	var obstacle: Obstacle = pool.pick_random().instantiate()
	entities.add_child(obstacle)
	obstacle.global_position = grid.cell_to_global(cell)
	grid.set_obstacle(cell, true)
	obstacle.broken.connect(func():
		grid.set_obstacle(cell, false)
		room.obstacle_layout_changed.emit())
	_obstacles.append(obstacle)
	return true


func _clear_obstacles() -> void:
	for obstacle in _obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	_obstacles.clear()
	room.grid.obstacle_cells.clear()
	room.obstacle_layout_changed.emit()
