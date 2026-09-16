extends Node2D
class_name Dungeon

@export var room_count: int = 12
@export var start_room_scene: PackedScene
@export var normal_room_scenes: Array[PackedScene] = []
@export var boss_room_scene: PackedScene
@export var enemy_scenes: Array[PackedScene] = []
@export var room_world_size := Vector2(432, 224)

@onready var room_container: Node2D = $RoomContainer
@onready var entities: Node2D = $Entities

var layout: Dictionary = {}
var current_grid_pos: Vector2i = Vector2i.ZERO
var current_room: Node2D = null
var player: Player
var can_travel: bool = true
const TRAVEL_COOLDOWN := 0.3

func _ready() -> void:
	add_to_group("dungeon")
	layout = DungeonGenerator.generate(room_count)
	player = get_tree().get_first_node_in_group("player")
	_load_room(Vector2i.ZERO, DungeonGenerator.SOUTH)


func travel(direction: Vector2i) -> void:
	if not can_travel:
		return
	var next_pos: Vector2i = current_grid_pos + direction
	if layout.has(next_pos):
		can_travel = false
		_load_room(next_pos, direction)
		get_tree().create_timer(TRAVEL_COOLDOWN).timeout.connect(func(): can_travel = true)

func _load_room(grid_pos: Vector2i, entered_from: Vector2i) -> void:
	var data: RoomData = layout[grid_pos]

	if current_room:
		current_room.queue_free()

	var scene: PackedScene
	match data.type:
		RoomData.Type.START: scene = start_room_scene
		RoomData.Type.BOSS: scene = boss_room_scene
		_: 
			if data.scene_path == "":
				scene = normal_room_scenes[randi() % normal_room_scenes.size()]
				data.scene_path = scene.resource_path
			else:
				scene = load(data.scene_path)

	current_room = scene.instantiate()
	room_container.add_child(current_room)
	current_room.setup(data, [] as Array[PackedScene] if data.type == RoomData.Type.START else enemy_scenes, entities)
	current_room.room_cleared.connect(func(): data.cleared = true)

	current_grid_pos = grid_pos

	if data.type == RoomData.Type.START:
		player.global_position = current_room.global_position
	else:
		var entrance_direction := entered_from * -1
		var half_size := room_world_size / 2.0
		var distance_from_wall := 40.0

		var spawn_offset := Vector2(
			entrance_direction.x * (half_size.x - distance_from_wall),
			entrance_direction.y * (half_size.y - distance_from_wall)
		)

		player.global_position = current_room.global_position + spawn_offset

	player.set_camera_bounds(
		current_room.global_position,
		room_world_size
	)
