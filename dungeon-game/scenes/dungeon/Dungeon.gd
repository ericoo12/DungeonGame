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

@export var room_count: int = 12
@export var start_room_scene: PackedScene
@export var normal_room_scenes: Array[PackedScene] = []
@export var boss_room_scene: PackedScene
@export var item_room_scene: PackedScene
@export var item_pool_folder: String = "res://scenes/items/item_data/"

var item_pool: Array[ItemBase] = []

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

func _ready() -> void:
	add_to_group("dungeon")
	EventBus.boss_defeated.connect(_on_boss_defeated)
	player = get_tree().get_first_node_in_group("player")
	
	easy_enemy_scenes = _load_scenes_from_folder(easy_enemy_folder)
	medium_enemy_scenes = _load_scenes_from_folder(medium_enemy_folder)
	hard_enemy_scenes = _load_scenes_from_folder(hard_enemy_folder)
	boss_scenes = _load_scenes_from_folder(boss_folder)
	item_pool = _load_items_from_folder(item_pool_folder)
	
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

	var result := DungeonGenerator.generate(room_count)
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
	current_room.setup(data, room_distances.get(grid_pos, 0), self, entities)
	current_room.room_cleared.connect(func(): data.cleared = true)

	current_grid_pos = grid_pos

	
	var entrance_direction := entered_from * -1
	var half_size := room_world_size / 2.0
	var distance_from_wall := 50.0

	var spawn_offset := Vector2(
		entrance_direction.x * (half_size.x - distance_from_wall),
		entrance_direction.y * (half_size.y - distance_from_wall)
	)

	player.global_position = current_room.global_position + spawn_offset
	player.set_camera_bounds(current_room.global_position, room_world_size)
	player.reset_position_history()
	player.reset_followers_position()

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
