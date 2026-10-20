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
@export var shop_room_scene: PackedScene

@export_group("Final boss")
## On this stage the boss room is the final boss's own arena with the final boss in it
## (instead of boss_room_scene + a random boss from boss_folder). 0 = never.
@export var final_boss_stage: int = 3
@export var final_boss_room_scene: PackedScene = preload("res://scenes/final_boss/FinalBossRoom.tscn")
@export var final_boss_scene: PackedScene = preload("res://scenes/final_boss/DoktorMugg.tscn")
@export_group("")
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
## After a room's first enemy is picked, chance that each further pick is from the same
## family (EnemyBase.family) if that family exists in the rolled tier. 0 = fully mixed rooms.
@export_range(0.0, 1.0) var enemy_family_affinity: float = 0.75
@export_group("")

@export_group("Shop")
## Default prices in ducks (an item's own ItemBase.shop_price overrides these).
## Economy: a cleared room drops ~0.85 ducks on average, plus pots/trash bags.
@export var shop_item_price: int = 7
@export var shop_active_item_price: int = 8
## Extra ducks on top of the default price for Uncommon / Rare items.
@export var uncommon_price_bonus: int = 2
@export var rare_price_bonus: int = 5
## The rightmost shop spot sells a declogger (when the shop has 2+ spots).
@export var shop_declogger_price: int = 3
@export_group("")

@export_group("Item rarity")
## Relative chance per item of each rarity (ItemBase.rarity) in item rooms and shops,
## plus how much each point of luck adds. With 25 common / 31 uncommon / 11 rare items
## at 0 luck: ~57% common, ~35% uncommon, ~8% rare per pick (rare ~11% at 4 luck).
@export var common_weight: float = 10.0
@export var uncommon_weight: float = 5.0
@export var rare_weight: float = 3.0
@export var uncommon_weight_per_luck: float = 0.5
@export var rare_weight_per_luck: float = 0.5
@export_group("")

@export_group("Drops")
## Clogged chest-toilets (Toilet.gd): this table is rolled chest_toilet_drops times.
@export var toilet_chest_drops: DropTable = preload("res://scenes/dungeon/drops/toilet_chest_drops.tres")
@export var chest_toilet_drops: Vector2i = Vector2i(2, 3)
## Share of normal rooms that get a chest-toilet (DungeonGenerator).
@export_range(0.0, 1.0) var chest_toilet_chance: float = 0.15
## Rolled once when a normal room is cleared (luck-scaled, see DropTable).
@export var room_clear_drops: DropTable
@export_group("")

var breakable_obstacle_scenes: Array[PackedScene] = []
var solid_obstacle_scenes: Array[PackedScene] = []

## Enemy difficulty follows the STAGE, not how far a room is from the start (the player
## only gets stronger from items, not from walking further into a floor).
## Stage < medium_enemies_from_stage: easy only. From it: easy + medium. From
## hard_enemies_from_stage: easy + medium + hard. Mix per tier in RoomBase (TIER_WEIGHTS_*).
@export var medium_enemies_from_stage: int = 2
@export var hard_enemies_from_stage: int = 3
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
	_cache_enemy_families()
	
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

	var result := DungeonGenerator.generate(get_room_count_for_stage(GameState.current_stage),
		0.1, 1, chest_toilet_chance)
	layout = result.layout
	room_distances = result.distances
	current_room = null
	_load_room(Vector2i.ZERO, DungeonGenerator.SOUTH)

	player.global_position = current_room.global_position  # true initial spawn only — centers the player
	_apply_room_camera_bounds()
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

## Through an unclogged toilet (Toilet.gd): to the linked room, arriving at its toilet.
func travel_through_toilet(target: Vector2i) -> void:
	if not can_travel or not layout.has(target):
		return
	can_travel = false
	_load_room.call_deferred(target, Vector2i.ZERO)  # deferred: called from a physics callback
	get_tree().create_timer(TRAVEL_COOLDOWN).timeout.connect(func(): can_travel = true)


## entered_from = direction travelled (door), or ZERO when arriving through a toilet.
func _load_room(grid_pos: Vector2i, entered_from: Vector2i) -> void:
	for proj in get_tree().get_nodes_in_group("projectiles"):
		proj.queue_free()
		
	for pickup in get_tree().get_nodes_in_group("item_pickups"):
		pickup.queue_free()

	# Floor effects left in the previous room (e.g. Nosebleed puddles). They live in the
	# dungeon-wide GroundEffects layer, and every room loads at the same spot, so they'd
	# otherwise show up in the new room.
	for effect in get_tree().get_nodes_in_group("room_effects"):
		effect.queue_free()

	# Obstacles live in the Entities container (for y-sorting), not in the room scene,
	# so they don't die with the room and must be cleared here.
	for obstacle in get_tree().get_nodes_in_group("obstacles"):
		obstacle.queue_free()
	for prop in get_tree().get_nodes_in_group("room_props"):  # toilets
		prop.queue_free()

	var data: RoomData = layout[grid_pos]

	for child in room_container.get_children():
		child.queue_free()
	current_room = null

	var scene: PackedScene
	match data.type:
		RoomData.Type.START: scene = start_room_scene
		RoomData.Type.BOSS: scene = final_boss_room_scene if is_final_boss_stage() else boss_room_scene
		RoomData.Type.ITEM: scene = item_room_scene
		RoomData.Type.SHOP: scene = shop_room_scene
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


	
	if entered_from == Vector2i.ZERO and current_room.toilet:
		player.global_position = current_room.toilet.get_arrival_point()
	else:
		player.global_position = _room_entry_position(entered_from)
	_apply_room_camera_bounds()
	player.reset_position_history()
	player.reset_followers_position()
	EventBus.room_entered.emit()

func is_final_boss_stage() -> bool:
	return final_boss_stage > 0 and GameState.current_stage == final_boss_stage and final_boss_room_scene != null


## Normal rooms: room center + get_entry_offset(). The final boss arena is bigger and
## knows its own size.
func _room_entry_position(entered_from: Vector2i) -> Vector2:
	if current_room is FinalBossArena:
		return (current_room as FinalBossArena).get_entry_position(entered_from, ENTRY_DISTANCE_FROM_WALL)
	return current_room.global_position + get_entry_offset(entered_from * -1)


func _apply_room_camera_bounds() -> void:
	if current_room is FinalBossArena:
		var bounds := (current_room as FinalBossArena).get_arena_bounds()
		player.set_camera_bounds(bounds.get_center(), bounds.size)
	else:
		player.set_camera_bounds(current_room.global_position, room_world_size)


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


# resource_path -> family / spawn_weight, read once at startup so spawning doesn't
# instantiate to ask.
var _enemy_families: Dictionary = {}
var _enemy_weights: Dictionary = {}


func _cache_enemy_families() -> void:
	_enemy_families.clear()
	_enemy_weights.clear()
	for pool in [easy_enemy_scenes, medium_enemy_scenes, hard_enemy_scenes]:
		for scene: PackedScene in pool:  # typed: the outer list is untyped, so `scene` would be Variant
			var instance: Node = scene.instantiate()
			var enemy := instance as EnemyBase
			_enemy_families[scene.resource_path] = enemy.family if enemy else &""
			_enemy_weights[scene.resource_path] = enemy.spawn_weight if enemy else 1.0
			instance.free()


func get_enemy_weight(scene: PackedScene) -> float:
	return _enemy_weights.get(scene.resource_path, 1.0)


func get_enemy_family(scene: PackedScene) -> StringName:
	return _enemy_families.get(scene.resource_path, &"")


## Every regular enemy (any tier) of `family`.
func get_family_scenes(family: StringName) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	if family == &"":
		return result
	for pool in [easy_enemy_scenes, medium_enemy_scenes, hard_enemy_scenes]:
		for scene: PackedScene in pool:
			if get_enemy_family(scene) == family:
				result.append(scene)
	return result


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


# --- Item picks ------------------------------------------------------------------

func get_rarity_weight(item: ItemBase) -> float:
	var luck := Luck.effective()
	match item.rarity:
		ItemBase.Rarity.UNCOMMON: return uncommon_weight + uncommon_weight_per_luck * luck
		ItemBase.Rarity.RARE: return rare_weight + rare_weight_per_luck * luck
	return common_weight


## Up to `count` different items not picked up / reserved yet this run, drawn by rarity
## weight (no repeats). Doesn't reserve them; the caller does.
func pick_items(count: int) -> Array[ItemBase]:
	var pool: Array[ItemBase] = []
	for candidate in item_pool:
		if not GameState.picked_up_items.has(candidate):
			pool.append(candidate)
	var result: Array[ItemBase] = []
	while result.size() < count and not pool.is_empty():
		var total := 0.0
		for item in pool:
			total += get_rarity_weight(item)
		var roll := randf() * total
		var chosen: ItemBase = pool[-1]
		for item in pool:
			roll -= get_rarity_weight(item)
			if roll <= 0.0:
				chosen = item
				break
		result.append(chosen)
		pool.erase(chosen)
	return result


func get_default_price(item: ItemBase) -> int:
	var price := shop_active_item_price if item is ActiveItem else shop_item_price
	match item.rarity:
		ItemBase.Rarity.UNCOMMON: price += uncommon_price_bonus
		ItemBase.Rarity.RARE: price += rare_price_bonus
	return price
