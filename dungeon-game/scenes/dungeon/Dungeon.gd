extends Node2D
class_name Dungeon

@export var easy_enemy_folder: String = "res://scenes/enemies/regular_enemies/easy/"
@export var medium_enemy_folder: String = "res://scenes/enemies/regular_enemies/medium/"
@export var hard_enemy_folder: String = "res://scenes/enemies/regular_enemies/hard/"
@export var boss_folder: String = "res://scenes/enemies/bosses/"

var easy_enemy_scenes: Array[PackedScene] = []
var medium_enemy_scenes: Array[PackedScene] = []
var hard_enemy_scenes: Array[PackedScene] = []
var boss_scenes: Array[PackedScene] = []

@export var room_count: int = 12          # room count on stage 1
@export var rooms_per_stage: int = 2      # extra rooms added for each stage beyond 1
@export var max_room_count: int = 20      # cap so late stages don't get huge
@export var start_room_scene: PackedScene
@export var normal_room_scenes: Array[PackedScene] = []
@export var boss_room_scene: PackedScene
@export var item_room_scene: PackedScene
@export var item_pool_folder: String = "res://scenes/items/item_data/"

var item_pool: Array[ItemBase] = []

@export_group("Obstacles")
## One folder; each scene's Obstacle.breakable flag decides which pool it lands in.
@export var obstacle_folder: String = "res://scenes/obstacles/"
@export_range(0.0, 1.0) var obstacle_spawn_chance: float = 0.35   # per obstacle_spawn_points marker
@export_range(0.0, 1.0) var breakable_obstacle_ratio: float = 0.6 # breakable vs solid
@export var obstacle_layout_candidates: int = 16                  # layouts generated + scored per room
@export var validate_obstacle_layouts: bool = true                # false = plain random roll, no checks
@export_group("")

@export_group("Enemy spawns")
## Normal rooms place enemies on random reachable cells instead of enemy_spawn_points
## markers (boss/item rooms still use their markers). false = old marker behavior.
@export var use_procedural_enemy_spawns: bool = true
@export var enemy_count_min: int = 2
@export var enemy_count_max: int = 4
@export var extra_enemies_per_stage: float = 0.5   # +1 enemy every 2 stages by default
@export var enemy_min_entry_distance: float = 5.0  # in cells (16px) from any door entry point
@export var enemy_spawn_samples: int = 8           # best-candidate samples per enemy (higher = more spread out)
@export_group("")

var breakable_obstacle_scenes: Array[PackedScene] = []
var solid_obstacle_scenes: Array[PackedScene] = []

@export var easy_max_distance: int = 2    # rooms this close to start only pull from easy_enemy_scenes
@export var hard_min_distance: int = 5    # rooms this far or farther can pull from hard_enemy_scenes
@export var room_world_size := Vector2(432, 224)
var room_distances: Dictionary = {}
@export var floor_variants: Array[RoomFloorVariant] = []
var current_floor_variant: RoomFloorVariant = null

@onready var room_container: Node2D = $RoomContainer
@onready var entities: Node2D = $Entities

const STAGE_DOOR_SCENE := preload("res://scenes/dungeon/StageDoor.tscn")

var layout: Dictionary = {}
var current_grid_pos: Vector2i = Vector2i.ZERO
var current_room: Node2D = null
var player: Player
var can_travel: bool = true
const TRAVEL_COOLDOWN := 0.3
const ENTRY_DISTANCE_FROM_WALL := 50.0

func _ready() -> void:
	add_to_group("dungeon")
	EventBus.boss_defeated.connect(_on_boss_defeated)
	player = get_tree().get_first_node_in_group("player")
	
	easy_enemy_scenes = _load_scenes_from_folder(easy_enemy_folder)
	medium_enemy_scenes = _load_scenes_from_folder(medium_enemy_folder)
	hard_enemy_scenes = _load_scenes_from_folder(hard_enemy_folder)
	boss_scenes = _load_scenes_from_folder(boss_folder)
	item_pool = _load_items_from_folder(item_pool_folder)
	_load_obstacle_pools()
	
	_generate_and_load_floor()


func _load_scenes_from_folder(path: String) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Dungeon: could not open folder " + path)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tscn"):
			var scene: PackedScene = load(path + file_name)
			if scene:
				result.append(scene)
		file_name = dir.get_next()
	dir.list_dir_end()

	return result
	

func _generate_and_load_floor() -> void:
	if not floor_variants.is_empty():
		current_floor_variant = floor_variants[randi() % floor_variants.size()]

	var result := DungeonGenerator.generate(get_room_count_for_stage(GameState.current_stage))
	layout = result.layout
	room_distances = result.distances
	current_room = null
	_load_room(Vector2i.ZERO, DungeonGenerator.SOUTH)

	player.global_position = current_room.global_position  # true initial spawn only — centers the player
	player.set_camera_bounds(current_room.global_position, room_world_size)
	player.reset_position_history()
	player.reset_followers_position()


func _on_boss_defeated() -> void:
	pass


func travel(direction: Vector2i) -> void:
	if not can_travel:
		return
	var next_pos: Vector2i = current_grid_pos + direction
	if layout.has(next_pos):
		can_travel = false
		_load_room(next_pos, direction)
		get_tree().create_timer(TRAVEL_COOLDOWN).timeout.connect(func(): can_travel = true)

func _load_room(grid_pos: Vector2i, entered_from: Vector2i) -> void:
	for proj in get_tree().get_nodes_in_group("projectiles"):
		proj.queue_free()
		
	for pickup in get_tree().get_nodes_in_group("item_pickups"):
		pickup.queue_free()

	# Obstacles live in the Entities container (for y-sorting), not in the room scene,
	# so they don't die with the room and must be cleared here.
	for obstacle in get_tree().get_nodes_in_group("obstacles"):
		obstacle.queue_free()

	var data: RoomData = layout[grid_pos]

	for child in room_container.get_children():
		child.queue_free()
	current_room = null

	var scene: PackedScene
	match data.type:
		RoomData.Type.START: scene = start_room_scene
		RoomData.Type.BOSS: scene = boss_room_scene
		RoomData.Type.ITEM: scene = item_room_scene
		_: 
			if data.scene_path == "":
				scene = normal_room_scenes[randi() % normal_room_scenes.size()]
				data.scene_path = scene.resource_path
			else:
				scene = load(data.scene_path)

	current_room = scene.instantiate()
	room_container.add_child(current_room)
	current_grid_pos = grid_pos   # moved up from further down
	current_room.setup(data, room_distances.get(grid_pos, 0), self, entities)
	current_room.room_cleared.connect(func(): data.cleared = true)


	
	var entrance_direction := entered_from * -1
	player.global_position = current_room.global_position + get_entry_offset(entrance_direction)
	player.set_camera_bounds(current_room.global_position, room_world_size)
	player.reset_position_history()
	player.reset_followers_position()

func get_enemy_count_for_stage(stage: int) -> int:
	var base := randi_range(enemy_count_min, maxi(enemy_count_min, enemy_count_max))
	return base + int(floor((stage - 1) * extra_enemies_per_stage))


func get_room_count_for_stage(stage: int) -> int:
	return mini(room_count + (stage - 1) * rooms_per_stage, max_room_count)


func advance_to_next_stage() -> void:
	GameState.advance_stage()
	_generate_and_load_floor()


func _load_items_from_folder(path: String) -> Array[ItemBase]:
	var result: Array[ItemBase] = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Dungeon: could not open folder " + path)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var item: ItemBase = load(path + file_name)
			if item:
				result.append(item)
		file_name = dir.get_next()
	dir.list_dir_end()

	return result


## Where the player appears (relative to room center) when entering through the door on
## side `door_dir`. Also used by obstacle placement to keep entry points clear.
func get_entry_offset(door_dir: Vector2i) -> Vector2:
	var half_size := room_world_size / 2.0
	return Vector2(
		door_dir.x * (half_size.x - ENTRY_DISTANCE_FROM_WALL),
		door_dir.y * (half_size.y - ENTRY_DISTANCE_FROM_WALL)
	)


func _load_obstacle_pools() -> void:
	breakable_obstacle_scenes.clear()
	solid_obstacle_scenes.clear()
	for scene in _load_scenes_from_folder(obstacle_folder):
		var instance := scene.instantiate()
		var obstacle := instance as Obstacle
		if obstacle == null:
			push_warning("Dungeon: %s is not an Obstacle, skipped" % scene.resource_path)
		elif obstacle.breakable:
			breakable_obstacle_scenes.append(scene)
		else:
			solid_obstacle_scenes.append(scene)
		instance.free()


## Returns the RoomData.Type of the room next to the current one, or -1 if there's none.
func get_neighbor_type(direction: Vector2i) -> int:
	var data: RoomData = layout.get(current_grid_pos + direction)
	return data.type if data else -1
