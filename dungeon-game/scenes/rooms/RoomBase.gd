extends Node2D
class_name RoomController

signal room_cleared

var doors: Dictionary = {}
var _enemy_count: int = 0

@onready var floor_top_left: Sprite2D = $Background/TopLeft
@onready var floor_top_right: Sprite2D = $Background/TopRigth
@onready var floor_bottom_left: Sprite2D = $Background/BotLeft
@onready var floor_bottom_right: Sprite2D = $Background/BotRigth
@onready var stage_door: StageDoor = get_node_or_null("Doors/StageDoor")
var _is_boss_room: bool = false
var _entities_container: Node2D = null
var _current_room_data: RoomData = null
const ITEM_PICKUP_SCENE := preload("res://scenes/items/ItemPickup.tscn")

func _ready() -> void:
	for dir in [DungeonGenerator.NORTH, DungeonGenerator.SOUTH, DungeonGenerator.EAST, DungeonGenerator.WEST]:
		var node_name: String = _door_node_name(dir)
		if has_node("Doors/" + node_name):
			doors[dir] = get_node("Doors/" + node_name)


func setup(room_data: RoomData, distance: int, dungeon: Dungeon, entities_container: Node2D) -> void:
	_current_room_data = room_data
	_entities_container = entities_container
	_apply_floor_variant(dungeon.current_floor_variant)

	for dir in doors.keys():
		var door: Door = doors[dir]
		door.direction = dir
		var has_connection: bool = room_data.doors[dir]
		door.visible = has_connection
		if has_connection:
			door.set_unlocked(room_data.cleared or room_data.type == RoomData.Type.ITEM)
		else:
			door.set_unlocked(false)

	if room_data.type == RoomData.Type.BOSS and room_data.stage_door_activated and stage_door:
		stage_door.activate()

	if room_data.cleared or room_data.type == RoomData.Type.START:
		return

	if room_data.type == RoomData.Type.BOSS:
		_spawn_boss(dungeon, entities_container)
	elif room_data.type == RoomData.Type.ITEM:
		_spawn_pickup(room_data, dungeon)
	else:
		_spawn_enemies(distance, dungeon, entities_container)
		


func _spawn_enemies(distance: int, dungeon: Dungeon, entities_container: Node2D) -> void:
	var pool: Array[PackedScene] = _pick_pool(distance, dungeon)
	if pool.is_empty():
		return

	var spawn_points := get_tree().get_nodes_in_group("enemy_spawn_points")
	var local_points: Array = []
	for p in spawn_points:
		if is_ancestor_of(p):
			local_points.append(p)

	for point in local_points:
		var scene: PackedScene = pool[randi() % pool.size()]
		var enemy := scene.instantiate()
		entities_container.add_child(enemy)
		enemy.global_position = point.global_position
		enemy.tree_exiting.connect(_on_enemy_removed)
		_enemy_count += 1

	if _enemy_count == 0:
		_unlock_all_doors()


func _pick_pool(distance: int, dungeon: Dungeon) -> Array[PackedScene]:
	if distance >= dungeon.hard_min_distance:
		return dungeon.hard_enemy_scenes
	elif distance > dungeon.easy_max_distance:
		return dungeon.medium_enemy_scenes
	else:
		return dungeon.easy_enemy_scenes


func _on_enemy_removed() -> void:
	_enemy_count -= 1
	if _enemy_count <= 0:
		_unlock_all_doors()
		room_cleared.emit()
		if stage_door:
			stage_door.activate()
			_current_room_data.stage_door_activated = true


func _unlock_all_doors() -> void:
	for dir in doors.keys():
		var door: Door = doors[dir]
		if door.visible:
			door.set_unlocked(true)


func _door_node_name(dir: Vector2i) -> String:
	if dir == DungeonGenerator.NORTH: return "North"
	if dir == DungeonGenerator.SOUTH: return "South"
	if dir == DungeonGenerator.EAST: return "East"
	return "West"


func _spawn_boss(dungeon: Dungeon, entities_container: Node2D) -> void:
	if dungeon.boss_scenes.is_empty():
		return

	var scene: PackedScene = dungeon.boss_scenes[randi() % dungeon.boss_scenes.size()]

	var spawn_points := get_tree().get_nodes_in_group("enemy_spawn_points")
	var local_points: Array = []
	for p in spawn_points:
		if is_ancestor_of(p):
			local_points.append(p)

	var spawn_pos: Vector2 = local_points[0].global_position if local_points.size() > 0 else global_position

	var boss := scene.instantiate()
	entities_container.add_child(boss)
	boss.global_position = spawn_pos
	boss.tree_exiting.connect(_on_enemy_removed)
	_enemy_count += 1


func _apply_floor_variant(variant: RoomFloorVariant) -> void:
	if not variant or not variant.texture:
		return
	floor_top_left.texture = variant.texture
	floor_top_right.texture = variant.texture
	floor_bottom_left.texture = variant.texture
	floor_bottom_right.texture = variant.texture


func _spawn_stage_door() -> void:
	var spawn_points := get_tree().get_nodes_in_group("enemy_spawn_points")
	var local_points: Array = []
	for p in spawn_points:
		if is_ancestor_of(p):
			local_points.append(p)

	var spawn_pos: Vector2 = local_points[0].global_position if local_points.size() > 0 else global_position

	var door := Dungeon.STAGE_DOOR_SCENE.instantiate()
	_entities_container.add_child(door)
	door.global_position = spawn_pos


func _spawn_pickup(room_data: RoomData, dungeon: Dungeon) -> void:
	var chosen_item: ItemBase

	if room_data.assigned_item:
		chosen_item = room_data.assigned_item
	else:
		var available: Array[ItemBase] = []
		for candidate in dungeon.item_pool:
			if not GameState.picked_up_items.has(candidate):
				available.append(candidate)

		if available.is_empty():
			return

		chosen_item = available[randi() % available.size()]
		room_data.assigned_item = chosen_item
		GameState.picked_up_items.append(chosen_item)

	var spawn_points := get_tree().get_nodes_in_group("enemy_spawn_points")
	var local_points: Array = []
	for p in spawn_points:
		if is_ancestor_of(p):
			local_points.append(p)
	var spawn_pos: Vector2 = local_points[0].global_position if local_points.size() > 0 else global_position

	var pickup: ItemPickup = ITEM_PICKUP_SCENE.instantiate()
	_entities_container.add_child(pickup)
	pickup.global_position = spawn_pos
	pickup.setup(chosen_item)
	pickup.item_taken.connect(func():
		room_data.cleared = true
		room_cleared.emit()
	)
	
