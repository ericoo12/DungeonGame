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
var _dungeon: Dungeon = null
const ITEM_PICKUP_SCENE := preload("res://scenes/items/ItemPickup.tscn")

## Walkability grid built from WallBlockers + live obstacles.
## Shared with enemy pathfinding: grid.to_astar(), grid.is_walkable(cell), etc.
var grid: RoomGrid = null
## Cells (16px, room-local) the grid covers: the interior plus the wall ring around it.
## Cells outside are treated as solid.
@export var grid_rect: Rect2i = Rect2i(-12, -7, 24, 13)
signal obstacle_layout_changed  # emitted when an obstacle breaks (grid already updated)

func _ready() -> void:
	for dir in [DungeonGenerator.NORTH, DungeonGenerator.SOUTH, DungeonGenerator.EAST, DungeonGenerator.WEST]:
		var node_name: String = _door_node_name(dir)
		if has_node("Doors/" + node_name):
			doors[dir] = get_node("Doors/" + node_name)


func setup(room_data: RoomData, distance: int, dungeon: Dungeon, entities_container: Node2D) -> void:
	_current_room_data = room_data
	_entities_container = entities_container
	_dungeon = dungeon
	_apply_floor_variant(dungeon.current_floor_variant)

	grid = RoomGrid.new(self, grid_rect)
	_add_wall_blockers_to_grid()

	for dir in doors.keys():
		var door: Door = doors[dir]
		door.direction = dir
		var has_connection: bool = room_data.doors[dir]
		door.visible = has_connection
		if has_connection:
			door.set_unlocked(room_data.cleared or room_data.type == RoomData.Type.ITEM)
			door.set_style(_door_style(room_data.type, dungeon.get_neighbor_type(dir)))
		else:
			door.set_unlocked(false)

	if room_data.type == RoomData.Type.BOSS and room_data.stage_door_activated and stage_door:
		stage_door.activate()

	# Before the cleared-check: obstacles persist after a room is cleared.
	if room_data.type == RoomData.Type.NORMAL:
		_spawn_obstacles(room_data, dungeon)
	_respawn_pending_drops()

	if room_data.cleared or room_data.type == RoomData.Type.START:
		return

	if room_data.type == RoomData.Type.BOSS:
		_spawn_boss(dungeon, entities_container)
	elif room_data.type == RoomData.Type.ITEM:
		_spawn_pickup(room_data, dungeon)
	else:
		_spawn_enemies(distance, dungeon, entities_container)
		


func _spawn_enemies(distance: int, dungeon: Dungeon, entities_container: Node2D) -> void:
	# Where: procedural cells from the grid (runs after _spawn_obstacles, so the grid
	# already contains this room's obstacles), or the old hand-placed markers.
	var positions: Array[Vector2] = []
	if dungeon.use_procedural_enemy_spawns and grid != null:
		var count := dungeon.get_enemy_count_for_stage(GameState.current_stage)
		var cells := EnemySpawnPlanner.pick_cells(grid, _entry_cells(dungeon), count,
			dungeon.enemy_min_entry_distance, dungeon.enemy_spawn_samples)
		for cell in cells:
			positions.append(grid.cell_to_global(cell))
	else:
		for point in _local_group_nodes("enemy_spawn_points"):
			positions.append(point.global_position)

	# What: a mix of difficulty tiers, types drawn from a shuffle bag for variety.
	var scenes := _pick_enemy_scenes(positions.size(), distance, dungeon)

	for i in scenes.size():
		var enemy := scenes[i].instantiate()
		var extra := _pack_extra_count(enemy)
		_add_enemy(enemy, positions[i], entities_container)
		for pack_pos in _pack_positions(positions[i], extra):
			_add_enemy(scenes[i].instantiate(), pack_pos, entities_container)

	if _enemy_count == 0:
		_unlock_all_doors()


func _add_enemy(enemy: Node, pos: Vector2, entities_container: Node2D) -> void:
	entities_container.add_child(enemy)
	enemy.global_position = pos
	enemy.tree_exiting.connect(_on_enemy_removed)
	_enemy_count += 1


## Extra members to spawn alongside `enemy` (EnemyBase.pack_size), 0 for solo enemies.
func _pack_extra_count(enemy: Node) -> int:
	var e := enemy as EnemyBase
	if e == null or e.pack_size.y <= 1:
		return 0
	return maxi(randi_range(e.pack_size.x, e.pack_size.y) - 1, 0)


## `count` spawn points on the free tiles closest to `center` (walking distance on the
## grid, so pack members never end up behind a wall), with a little jitter.
func _pack_positions(center: Vector2, count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if count <= 0:
		return result
	var cells: Array = []
	if grid:
		var dist := grid.bfs(grid.global_to_cell(center))
		cells = dist.keys()
		cells.sort_custom(func(a, b): return dist[a] < dist[b])
		cells = cells.slice(1)  # first one is the leader's own tile
	for i in count:
		var base := grid.cell_to_global(cells[i]) if i < cells.size() else center
		result.append(base + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)))
	return result


## Chance per enemy of being drawn from [easy, medium, hard], by the room's tier
## (easy_max_distance / hard_min_distance on Dungeon). Empty pools are skipped automatically.
const TIER_WEIGHTS_EASY_ROOM := [1.0, 0.0, 0.0]
const TIER_WEIGHTS_MEDIUM_ROOM := [0.35, 0.65, 0.0]
const TIER_WEIGHTS_HARD_ROOM := [0.15, 0.35, 0.5]


func _pick_enemy_scenes(count: int, distance: int, dungeon: Dungeon) -> Array[PackedScene]:
	var tiers: Array = [dungeon.easy_enemy_scenes, dungeon.medium_enemy_scenes, dungeon.hard_enemy_scenes]
	var weights: Array = TIER_WEIGHTS_EASY_ROOM
	if distance >= dungeon.hard_min_distance:
		weights = TIER_WEIGHTS_HARD_ROOM
	elif distance > dungeon.easy_max_distance:
		weights = TIER_WEIGHTS_MEDIUM_ROOM

	# Shuffle bag per tier: every type in a tier appears once before any repeats.
	var bags: Array = [[], [], []]
	var result: Array[PackedScene] = []
	for i in count:
		var tier := _roll_tier(weights, tiers)
		if tier == -1:
			break
		if bags[tier].is_empty():
			bags[tier] = tiers[tier].duplicate()
			bags[tier].shuffle()
		result.append(bags[tier].pop_back())
	return result


func _roll_tier(weights: Array, tiers: Array) -> int:
	var total := 0.0
	for t in 3:
		if not tiers[t].is_empty():
			total += weights[t]
	if total <= 0.0:
		# The room's tiers are all empty (e.g. no medium enemies made yet): use any non-empty pool.
		for t in 3:
			if not tiers[t].is_empty():
				return t
		return -1
	var roll := randf() * total
	for t in 3:
		if tiers[t].is_empty():
			continue
		roll -= weights[t]
		if roll <= 0.0:
			return t
	for t in [2, 1, 0]:
		if not tiers[t].is_empty():
			return t
	return -1


func _on_enemy_removed() -> void:
	_enemy_count -= 1
	if _enemy_count <= 0:
		_unlock_all_doors()
		room_cleared.emit()
		_roll_room_clear_reward()
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
	

## Neighbor's type wins, so a door INTO a special room shows its style. If the neighbor
## is normal, the current room's type is used, so doors INSIDE a special room match it.
func _door_style(own_type: int, neighbor_type: int) -> Door.Style:
	for t in [neighbor_type, own_type]:
		if t == RoomData.Type.BOSS: return Door.Style.BOSS
		if t == RoomData.Type.ITEM: return Door.Style.ITEM
	return Door.Style.NORMAL


# --- Obstacles ---------------------------------------------------------------

func _spawn_obstacles(room_data: RoomData, dungeon: Dungeon) -> void:
	if grid == null:
		return
	var markers := _local_group_nodes("obstacle_spawn_points")
	if markers.is_empty():
		return

	if not room_data.obstacles_rolled:
		room_data.obstacle_state = _roll_obstacle_layout(room_data, dungeon, markers)
		room_data.obstacles_rolled = true

	for index in room_data.obstacle_state:
		var entry: Dictionary = room_data.obstacle_state[index]
		if index >= markers.size():
			continue
		var scene: PackedScene = load(entry.scene_path)
		if scene == null:
			continue
		var cell := grid.global_to_cell(markers[index].global_position)
		var obstacle: Obstacle = scene.instantiate()
		if entry.broken and not obstacle.leave_remains:
			obstacle.free()
			continue
		_entities_container.add_child(obstacle)
		obstacle.global_position = grid.cell_to_global(cell)  # snapped, so physics matches the grid
		if entry.broken:
			obstacle.show_as_broken()  # debris from an earlier visit: walkable, not in the grid
			continue
		grid.set_obstacle(cell, true)
		obstacle.broken.connect(func():
			entry.broken = true  # persists on RoomData: stays broken on revisit
			grid.set_obstacle(cell, false)
			obstacle_layout_changed.emit()
			if obstacle.drop_table:
				_spawn_drop(obstacle.drop_table.roll(), grid.cell_to_global(cell))
		)


func _roll_obstacle_layout(room_data: RoomData, dungeon: Dungeon, markers: Array) -> Dictionary:
	var marker_cells: Array[Vector2i] = []
	for marker in markers:
		marker_cells.append(grid.global_to_cell(marker.global_position))

	var clear_cells: Dictionary = {}

	# Where the player appears for each connected door: must be free and reachable.
	var entry_cells := _entry_cells(dungeon)
	for cell in entry_cells:
		_add_clearance(clear_cells, cell, 1)

	# Marker-placed enemies must not spawn inside/boxed in by obstacles (unkillable enemy =
	# softlock). Procedural enemies don't need this: they're only placed on cells that are
	# reachable AFTER obstacles exist (see EnemySpawnPlanner).
	var required_cells: Array[Vector2i] = []
	var marker_enemies: Array = [] if dungeon.use_procedural_enemy_spawns else _local_group_nodes("enemy_spawn_points")
	for point in marker_enemies:
		var cell := grid.global_to_cell(point.global_position)
		required_cells.append(cell)
		_add_clearance(clear_cells, cell, 1)

	return ObstaclePlacer.generate(
		grid, marker_cells, entry_cells, required_cells, clear_cells,
		dungeon.breakable_obstacle_scenes, dungeon.solid_obstacle_scenes,
		dungeon.obstacle_spawn_chance, dungeon.breakable_obstacle_ratio,
		dungeon.obstacle_layout_candidates, dungeon.validate_obstacle_layouts)


## Rectangle CollisionShape2Ds under the WallBlockers StaticBody2D (all walls in
## RoomBase; inherited rooms can add more) block the grid, so obstacle/enemy placement
## agrees with physics. Rotation is ignored: keep these axis-aligned.
## (ProjectileWalls is deliberately NOT read: it's the outer ring for shots/enemies.)
func _add_wall_blockers_to_grid() -> void:
	var blockers := get_node_or_null("WallBlockers")
	if blockers == null:
		return
	for child in blockers.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null or shape_node.disabled:
			continue
		var rect_shape := shape_node.shape as RectangleShape2D
		if rect_shape == null:
			continue
		var size := rect_shape.size * shape_node.global_scale.abs()
		grid.block_rect(Rect2(shape_node.global_position - size / 2.0, size))


## Grid cell where the player appears for each connected door of this room.
func _entry_cells(dungeon: Dungeon) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dir in DungeonGenerator.DIRECTIONS:
		if _current_room_data.doors.get(dir, false):
			cells.append(grid.global_to_cell(global_position + dungeon.get_entry_offset(dir)))
	return cells


func _add_clearance(cells: Dictionary, center: Vector2i, radius: int) -> void:
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			cells[center + Vector2i(dx, dy)] = true


## Nodes in `group` that belong to this room (same scoping as the spawn functions above).
func _local_group_nodes(group: String) -> Array:
	var result: Array = []
	for node in get_tree().get_nodes_in_group(group):
		if is_ancestor_of(node):
			result.append(node)
	return result


# --- Drops (luck-scaled rewards) -------------------------------------------------

## Normal rooms roll Dungeon.room_clear_drops once, when the last enemy dies.
func _roll_room_clear_reward() -> void:
	if _current_room_data == null or _current_room_data.type != RoomData.Type.NORMAL:
		return
	if _dungeon == null or _dungeon.room_clear_drops == null:
		return
	if not is_inside_tree() or is_queued_for_deletion():
		return  # enemies also "die" when the room/scene is torn down
	_spawn_drop(_dungeon.room_clear_drops.roll(), _free_cell_near(global_position))


## Spawns a drop into the Entities container. If the scene has a `collected` signal it's
## remembered on RoomData until picked up, so it's still there when you come back.
## `existing_entry` is passed when respawning a remembered drop.
func _spawn_drop(scene: PackedScene, global_pos: Vector2, existing_entry: Dictionary = {}) -> void:
	if scene == null or _entities_container == null:
		return
	var drop := scene.instantiate()
	if drop is Node2D:
		(drop as Node2D).position = _entities_container.to_local(global_pos)
	# Deferred: this runs from physics callbacks (obstacle hit) and tree_exiting (enemy died).
	_entities_container.add_child.call_deferred(drop)

	if not drop.has_signal("collected"):
		return
	var entry := existing_entry
	if entry.is_empty():
		entry = {"scene_path": scene.resource_path, "position": to_local(global_pos)}
		_current_room_data.pending_drops.append(entry)
	var room_data := _current_room_data
	drop.connect("collected", func(): room_data.pending_drops.erase(entry))


func _respawn_pending_drops() -> void:
	for entry in _current_room_data.pending_drops.duplicate():
		var scene := load(entry.scene_path) as PackedScene
		if scene == null:
			_current_room_data.pending_drops.erase(entry)
			continue
		_spawn_drop(scene, to_global(entry.position), entry)


## Walkable grid cell closest to `global_pos` (not in a wall or obstacle).
func _free_cell_near(global_pos: Vector2) -> Vector2:
	if grid == null:
		return global_pos
	var target := grid.global_to_cell(global_pos)
	var best := target
	var best_dist := INF
	for x in range(grid.rect.position.x, grid.rect.end.x):
		for y in range(grid.rect.position.y, grid.rect.end.y):
			var cell := Vector2i(x, y)
			if not grid.is_walkable(cell):
				continue
			var d := Vector2(cell - target).length_squared()
			if d < best_dist:
				best_dist = d
				best = cell
	return grid.cell_to_global(best)
