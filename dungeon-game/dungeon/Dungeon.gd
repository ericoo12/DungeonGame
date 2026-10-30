extends Node2D
class_name Dungeon

@export var easy_enemy_folder: String = "res://enemies/regular/easy/"
@export var medium_enemy_folder: String = "res://enemies/regular/medium/"
@export var hard_enemy_folder: String = "res://enemies/regular/hard/"
@export var boss_folder: String = "res://enemies/bosses/"

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
## Big normal rooms (2x1, 1x2, 2x2 map squares): built in code from the room's size.
@export var shaped_room_scene: PackedScene = preload("res://rooms/ShapedRoom.tscn")
## Chance each new normal room is a big one (DungeonGenerator.BIG_SHAPES), per stage
## (index 0 = stage 1; later stages use the last value).
@export var big_room_chance_by_stage: Array[float] = [0.1, 0.12, 0.15]
## Challenge room (sacrifice altars + 3 waves) and the chance a floor has one.
@export var challenge_room_scene: PackedScene = preload("res://rooms/challenge/ChallengeRoom.tscn")
## Chance a floor has a challenge room, per stage (index 0 = stage 1; stages past the
## end use the last value). Lower on stage 1, so you don't see one every run start.
@export var challenge_room_chance_by_stage: Array[float] = [0.25, 0.5, 0.5]
## > 0 overrides every stage's chance (debug/tests).
var challenge_room_chance_override: float = -1.0

@export_group("Final boss")
## On this stage the boss room is the final boss's own arena with the final boss in it
## (instead of boss_room_scene + a random boss from boss_folder). 0 = never.
@export var final_boss_stage: int = 3
@export var final_boss_room_scene: PackedScene = preload("res://enemies/doktor_mugg/FinalBossRoom.tscn")
@export var final_boss_scene: PackedScene = preload("res://enemies/doktor_mugg/DoktorMugg.tscn")
@export_group("")
@export var item_pool_folder: String = "res://data/items/"

var item_pool: Array[ItemBase] = []

@export_group("Obstacles")
## One folder; each scene's Obstacle.breakable flag decides which pool it lands in.
@export var obstacle_folder: String = "res://obstacles/"
@export_range(0.0, 1.0) var obstacle_spawn_chance: float = 0.35   # per obstacle_spawn_points marker
## Breakable (bags/baskets) vs solid (stones). Kept low so smashing everything isn't a
## chore; each breakable has a better drop chance instead (data/drops/obstacle_drops.tres).
@export_range(0.0, 1.0) var breakable_obstacle_ratio: float = 0.35
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
## The spot left of the declogger sells one full heart of healing (when the shop has 3+ spots).
@export var shop_heart_price: int = 3
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
@export var toilet_chest_drops: DropTable = preload("res://data/drops/toilet_chest_drops.tres")
@export var chest_toilet_drops: Vector2i = Vector2i(2, 3)
## Share of normal rooms that get a chest-toilet (DungeonGenerator).
@export_range(0.0, 1.0) var chest_toilet_chance: float = 0.15
## Stages up to and including this one start with the ITEM/SHOP portal toilets already
## unclogged, so early decloggers go to chest toilets. 0 = always clogged.
@export var free_special_rooms_until_stage: int = 1
## Rolled once when a normal room is cleared (luck-scaled, see DropTable).
@export var room_clear_drops: DropTable
## Added to the room clear drop chance when the player cleared the room without getting hit.
@export_range(0.0, 1.0) var no_damage_drop_bonus: float = 0.25
## Plunger pity: after this many room clears in a row without a declogger, the next
## room clear is guaranteed to drop one. 0 = off.
@export var declogger_pity_rooms: int = 4
@export var declogger_drop_scene: PackedScene = preload("res://pickups/DeclogPickup.tscn")
var _rooms_without_declogger: int = 0
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

const STAGE_DOOR_SCENE := preload("res://dungeon/StageDoor.tscn")

var layout: Dictionary = {}
## A map square of the current room (its home_cell(): always one of the room's own
## squares - an L's top-left box corner can be missing).
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
	boss_scenes = _load_boss_scenes(boss_folder)
	item_pool = _load_items_from_folder(item_pool_folder)
	_load_obstacle_pools()
	_cache_enemy_families()
	
	_generate_and_load_floor()
	if not GameState.start_loadout.is_empty():
		call_deferred("_apply_start_loadout")


## A run started from TestRoom's exit: hand the player the items picked there.
## Not counted as discoveries (the logbook only tracks real finds).
func _apply_start_loadout() -> void:
	var loadout := GameState.start_loadout
	GameState.start_loadout = {}
	if player == null:
		return
	var was_revealed := Discovery.reveal_all
	Discovery.reveal_all = true
	for item in loadout.get("items", []):
		if item is Item:
			player.add_item(item)
			GameState.picked_up_items.append(item)
	var active = loadout.get("active")
	if active is ActiveItem:
		player.add_active_item(active, int(loadout.get("charges", -1)))
		GameState.picked_up_items.append(active)
	player.add_ducks(int(loadout.get("ducks", 0)))
	Discovery.reveal_all = was_revealed


## Every boss under `path`, subfolders included (each boss can keep its own folder):
## the scenes whose root sets is_boss = true. Helper scenes in those folders (e.g. the
## Great Clog's HairClog) aren't bosses, so they're skipped.
func _load_boss_scenes(path: String) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Dungeon: could not open folder " + path)
		return result
	for file_name in dir.get_files():
		file_name = file_name.trim_suffix(".remap")  # exported builds
		if file_name.ends_with(".tscn"):
			var scene: PackedScene = load(path + file_name)
			if scene and _is_boss_scene(scene):
				result.append(scene)
	for sub in dir.get_directories():
		result.append_array(_load_boss_scenes(path + sub + "/"))
	return result


static func _is_boss_scene(scene: PackedScene) -> bool:
	var state := scene.get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == "is_boss":
			return state.get_node_property_value(0, i) == true
	return false


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
	Audio.play_normal_music()  # each stage has its own track (fades over on a new stage)
	if not floor_variants.is_empty():
		current_floor_variant = floor_variants[randi() % floor_variants.size()]

	var result := DungeonGenerator.generate(get_room_count_for_stage(GameState.current_stage),
		0.1, 1, chest_toilet_chance, get_challenge_room_chance(GameState.current_stage),
		get_big_room_chance(GameState.current_stage))
	layout = result.layout
	room_distances = result.distances
	if GameState.current_stage <= free_special_rooms_until_stage:
		_unclog_special_room_toilets()
	current_room = null
	_load_room(Vector2i.ZERO, DungeonGenerator.SOUTH)

	player.global_position = current_room.global_position  # true initial spawn only — centers the player
	_apply_room_camera_bounds()
	player.reset_position_history()
	player.reset_followers_position()


## Unclogs every PORTAL toilet that leads into an ITEM or SHOP room.
func _unclog_special_room_toilets() -> void:
	for data: RoomData in layout.values():
		if data.toilet_kind != RoomData.ToiletKind.PORTAL or not layout.has(data.toilet_target):
			continue
		var target: RoomData = layout[data.toilet_target]
		if target.type == RoomData.Type.ITEM or target.type == RoomData.Type.SHOP:
			data.toilet_unclogged = true


## Room clear reward roll: no-damage bonus + declogger pity (RoomBase calls this).
func roll_room_clear_drop(took_damage: bool) -> PackedScene:
	if room_clear_drops == null:
		return null
	var scene := room_clear_drops.roll(0.0 if took_damage else no_damage_drop_bonus)
	if scene == declogger_drop_scene:
		_rooms_without_declogger = 0
		return scene
	_rooms_without_declogger += 1
	if declogger_pity_rooms > 0 and _rooms_without_declogger >= declogger_pity_rooms:
		_rooms_without_declogger = 0
		return declogger_drop_scene
	return scene


func _on_boss_defeated() -> void:
	Discovery.record_stage_cleared(GameState.current_stage)  # main menu highscore


## Through the door on map square `from_cell` (default: the current room's top-left
## square), side `direction`. Big rooms span several squares, so the door's square
## decides which room is on the other side and which of its doors you come out of.
func travel(direction: Vector2i, from_cell: Variant = null) -> void:
	if not can_travel:
		return
	var cell: Vector2i = from_cell if from_cell is Vector2i else current_grid_pos
	var next_cell: Vector2i = cell + direction
	if layout.has(next_cell):
		can_travel = false
		_load_room(next_cell, direction, next_cell)
		get_tree().create_timer(TRAVEL_COOLDOWN).timeout.connect(func(): can_travel = true)

## Through an unclogged toilet (Toilet.gd): to the linked room, arriving at its toilet.
func travel_through_toilet(target: Vector2i) -> void:
	if not can_travel or not layout.has(target):
		return
	can_travel = false
	_load_room.call_deferred(target, Vector2i.ZERO)  # deferred: called from a physics callback
	get_tree().create_timer(TRAVEL_COOLDOWN).timeout.connect(func(): can_travel = true)


## entered_from = direction travelled (door), or ZERO when arriving through a toilet.
## grid_pos = any map square of the room. entry_cell = the map square of the door you
## come in through (big rooms; default: the room's home square).
func _load_room(grid_pos: Vector2i, entered_from: Vector2i, entry_cell: Variant = null) -> void:
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
	data.visited = true  # minimap
	grid_pos = data.home_cell()  # any square of a big room -> the same one every time

	for child in room_container.get_children():
		child.queue_free()
	current_room = null

	var scene: PackedScene
	match data.type if not data.is_multi_cell() else -1:
		-1: scene = shaped_room_scene
		RoomData.Type.START: scene = start_room_scene
		RoomData.Type.BOSS: scene = final_boss_room_scene if is_final_boss_stage() else boss_room_scene
		RoomData.Type.ITEM: scene = item_room_scene
		RoomData.Type.SHOP: scene = shop_room_scene
		RoomData.Type.CHALLENGE: scene = challenge_room_scene
		_: 
			if data.scene_path == "":
				scene = normal_room_scenes[randi() % normal_room_scenes.size()]
				data.scene_path = scene.resource_path
			else:
				scene = load(data.scene_path)

	current_room = scene.instantiate()
	room_container.add_child(current_room)
	current_grid_pos = grid_pos   # moved up from further down
	current_room.setup(data, room_distances.get(data.home_cell(), 0), self, entities)
	current_room.room_cleared.connect(func(): data.cleared = true)


	
	if entered_from == Vector2i.ZERO and current_room.toilet:
		player.global_position = current_room.toilet.get_arrival_point()
	else:
		player.global_position = _room_entry_position(entered_from, entry_cell if entry_cell is Vector2i else grid_pos)
	_apply_room_camera_bounds()
	player.reset_position_history()
	player.reset_followers_position()
	EventBus.room_entered.emit()

func get_challenge_room_chance(stage: int) -> float:
	if challenge_room_scene == null:
		return 0.0
	if challenge_room_chance_override >= 0.0:
		return challenge_room_chance_override
	if challenge_room_chance_by_stage.is_empty():
		return 0.0
	return challenge_room_chance_by_stage[clampi(stage - 1, 0, challenge_room_chance_by_stage.size() - 1)]


func is_final_boss_stage() -> bool:
	return final_boss_stage > 0 and GameState.current_stage == final_boss_stage and final_boss_room_scene != null


## Normal rooms: room center + get_entry_offset(). Bigger rooms (final boss arena,
## challenge room) know their own size.
func _room_entry_position(entered_from: Vector2i, entry_cell: Variant = null) -> Vector2:
	if not entry_cell is Vector2i:
		entry_cell = current_grid_pos
	if current_room.has_method("get_entry_position"):
		return current_room.get_entry_position(entered_from, ENTRY_DISTANCE_FROM_WALL)
	if current_room is RoomController:
		return (current_room as RoomController).get_door_entry_point(entry_cell, -entered_from, self)
	return current_room.global_position + get_entry_offset(entered_from * -1)


func get_big_room_chance(stage: int) -> float:
	if shaped_room_scene == null or big_room_chance_by_stage.is_empty():
		return 0.0
	return big_room_chance_by_stage[clampi(stage - 1, 0, big_room_chance_by_stage.size() - 1)]


func _apply_room_camera_bounds() -> void:
	if current_room.has_method("get_arena_bounds"):
		var bounds: Rect2 = current_room.get_arena_bounds()
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
## Type of the room on the other side of map square `cell`'s `direction` edge (-1 = none).
func get_neighbor_type_at(cell: Vector2i, direction: Vector2i) -> int:
	var data: RoomData = layout.get(cell + direction)
	return data.type if data else -1


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
