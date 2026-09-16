extends Node2D
class_name RoomController

signal room_cleared

var doors: Dictionary = {}
var _enemy_count: int = 0


func _ready() -> void:
	for dir in [DungeonGenerator.NORTH, DungeonGenerator.SOUTH, DungeonGenerator.EAST, DungeonGenerator.WEST]:
		var node_name: String = _door_node_name(dir)
		if has_node("Doors/" + node_name):
			doors[dir] = get_node("Doors/" + node_name)


func setup(room_data: RoomData, enemy_scenes: Array[PackedScene], entities_container: Node2D) -> void:
	for dir in doors.keys():
		var door: Door = doors[dir]
		door.direction = dir
		door.visible = room_data.doors[dir]
		if room_data.doors[dir]:
			door.set_unlocked(room_data.cleared)
		
	if not room_data.cleared and enemy_scenes.size() > 0:
		_spawn_enemies(enemy_scenes, entities_container)


func _spawn_enemies(enemy_scenes: Array[PackedScene], entities_container: Node2D) -> void:
	var spawn_points := get_tree().get_nodes_in_group("enemy_spawn_points")
	var local_points: Array = []
	for p in spawn_points:
		if is_ancestor_of(p):
			local_points.append(p)
	for point in local_points:
		var scene: PackedScene = enemy_scenes[randi() % enemy_scenes.size()]
		var enemy := scene.instantiate()
		entities_container.add_child(enemy)
		enemy.global_position = point.global_position
		enemy.tree_exiting.connect(_on_enemy_removed)
		_enemy_count += 1
	
	if _enemy_count == 0:
		_unlock_all_doors()


func _on_enemy_removed() -> void:
	_enemy_count -= 1
	if _enemy_count <= 0:
		_unlock_all_doors()
		room_cleared.emit()


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
