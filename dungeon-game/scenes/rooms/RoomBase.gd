extends Node2D
class_name RoomController

signal room_cleared

## Local room rectangle in gameplay units. Keep it aligned with the room walls.
@export var arena_bounds := Rect2(-216.0, -112.0, 432.0, 224.0)
const SIGHT_BLOCKER_MASK: int = 1 << 9


func get_arena_bounds() -> Rect2:
	return global_transform * arena_bounds


func clamp_to_arena(world_position: Vector2, margin: float = 0.0) -> Vector2:
	var bounds := get_arena_bounds()
	var inset := Vector2.ONE * maxf(margin, 0.0)
	inset = inset.min(bounds.size * 0.5)
	return world_position.clamp(bounds.position + inset, bounds.end - inset)


func get_entry_position(travel_direction: Vector2i, margin: float = 40.0) -> Vector2:
	var bounds := get_arena_bounds()
	var half_size := (bounds.size * 0.5 - Vector2.ONE * margin).max(Vector2.ZERO)
	return bounds.get_center() - Vector2(travel_direction) * half_size


## Call during physics processing. Green blocks are transparent to this query.
func has_clear_sight(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, SIGHT_BLOCKER_MASK)
	query.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


var doors: Dictionary = {}
var _enemy_count: int = 0

@onready var floor_top_left: Sprite2D = $Background/TopLeft
@onready var floor_top_right: Sprite2D = $Background/TopRigth
@onready var floor_bottom_left: Sprite2D = $Background/BotLeft
@onready var floor_bottom_right: Sprite2D = $Background/BotRigth
@onready var stage_door: StageDoor = get_node_or_null("Doors/StageDoor")
var _is_boss_room: bool = false
var _entities_container: Node2D = null

func _ready() -> void:
	for dir in [DungeonGenerator.NORTH, DungeonGenerator.SOUTH, DungeonGenerator.EAST, DungeonGenerator.WEST]:
		var node_name: String = _door_node_name(dir)
		if has_node("Doors/" + node_name):
			doors[dir] = get_node("Doors/" + node_name)


func setup(room_data: RoomData, distance: int, dungeon: Dungeon, entities_container: Node2D) -> void:
	_apply_floor_variant(dungeon.current_floor_variant)
	_is_boss_room = room_data.type == RoomData.Type.BOSS
	_entities_container = entities_container
	
	for dir in doors.keys():
		var door: Door = doors[dir]
		door.direction = dir
		var has_connection: bool = room_data.doors[dir]
		door.visible = has_connection

		if has_connection:
			door.set_unlocked(room_data.cleared)
		else:
			door.set_unlocked(false)  # no room this direction — stays solid, like a normal wall segment

	if room_data.cleared or room_data.type == RoomData.Type.START:
		return

	if room_data.type == RoomData.Type.BOSS:
		_spawn_boss(dungeon, entities_container)
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
	if boss.has_method("set_arena"):
		boss.set_arena(self)
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
