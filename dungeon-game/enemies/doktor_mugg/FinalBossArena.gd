extends RoomController
class_name FinalBossArena

## The final boss's room (Doktor Mugg): a 4x room-sized arena with its own walls
## (Perimeter) and blocks. Everything the boss AI needs from its room lives here, so the
## normal rooms (RoomBase) are untouched.

## Local room rectangle in gameplay units. Keep it aligned with the arena walls.
@export var arena_bounds := Rect2(-216.0, -112.0, 432.0, 224.0)
const SIGHT_BLOCKER_MASK: int = 1 << 9
const ROOM_ART := preload("res://rooms/RoomArt.gd")
## Dr Mugg's lair: room quarter art (RoomArt builds it at the arena's size).
const LAIR_TEX := preload("res://assets/sprites/tiles/special_rooms/dr_mugg_lair_224x112.png")
## Switch to the boss theme while this arena is loaded (back to normal music when it's
## left or the boss dies). Off for test scenes that only borrow the arena's walls.
@export var play_boss_music: bool = true


func _enter_tree() -> void:
	if play_boss_music:
		Audio.play_boss_music()
		if not EventBus.boss_defeated.is_connected(_on_boss_defeated_music):
			EventBus.boss_defeated.connect(_on_boss_defeated_music)


func _exit_tree() -> void:
	if play_boss_music:
		if EventBus.boss_defeated.is_connected(_on_boss_defeated_music):
			EventBus.boss_defeated.disconnect(_on_boss_defeated_music)
		var audio := get_node_or_null("/root/Audio")
		if audio:
			audio.play_normal_music()


func _on_boss_defeated_music() -> void:
	Audio.play_normal_music()


## RoomBase's normal-room colliders (WallBlockers for movement, ProjectileWalls for
## shots; 432x224) would sit inside this arena as invisible walls. The arena's own
## Perimeter (movement + projectile + sight layers) replaces both.
func _ready() -> void:
	super._ready()
	for wall_name in ["WallBlockers", "ProjectileWalls"]:
		var walls := get_node_or_null(wall_name)
		if walls:
			remove_child(walls)
			walls.queue_free()
	# The lair art replaces the sewer QuarterArt set up in the scene.
	var old_art := get_node_or_null("QuarterArt")
	if old_art:
		old_art.visible = false
	var art := ROOM_ART.build(LAIR_TEX, arena_bounds.size)
	art.position = arena_bounds.get_center()
	add_child(art)
	move_child(art, 0)


func setup(room_data: RoomData, distance: int, dungeon: Dungeon, entities_container: Node2D) -> void:
	super.setup(room_data, distance, dungeon, entities_container)
	# Obstacle art (e.g. the treasure vaults) is drawn y-sorted with the player.
	for node in find_children("*", "StaticBody2D", true, false):
		if node is ArenaObstacle:
			(node as ArenaObstacle).move_art_to(entities_container)


## Spawns the final boss (Dungeon.final_boss_scene, not a random normal boss) on the
## EnemySpawnPoints/BossSpawn marker and hands it this arena (navigation/sight).
func _spawn_boss(dungeon: Dungeon, entities_container: Node2D) -> void:
	if dungeon.final_boss_scene == null:
		super._spawn_boss(dungeon, entities_container)
		return
	var marker := get_node_or_null("EnemySpawnPoints/BossSpawn") as Node2D
	var spawn_pos: Vector2 = marker.global_position if marker else global_position
	var boss := dungeon.final_boss_scene.instantiate()
	entities_container.add_child(boss)
	boss.global_position = spawn_pos
	if boss.has_method("set_arena"):
		boss.set_arena(self)
	boss.tree_exiting.connect(_on_enemy_removed)
	_enemy_count += 1


func get_arena_bounds() -> Rect2:
	return global_transform * arena_bounds


func clamp_to_arena(world_position: Vector2, margin: float = 0.0) -> Vector2:
	var bounds := get_arena_bounds()
	var inset := Vector2.ONE * maxf(margin, 0.0)
	inset = inset.min(bounds.size * 0.5)
	return world_position.clamp(bounds.position + inset, bounds.end - inset)


## Where the player appears when walking in through the door on the other side of
## `travel_direction` (same rule as normal rooms, but for the arena's size).
func get_entry_position(travel_direction: Vector2i, margin: float = 40.0) -> Vector2:
	var bounds := get_arena_bounds()
	var half_size := (bounds.size * 0.5 - Vector2.ONE * margin).max(Vector2.ZERO)
	return bounds.get_center() - Vector2(travel_direction) * half_size


## Call during physics processing. Green blocks are transparent to this query.
func has_clear_sight(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, SIGHT_BLOCKER_MASK)
	query.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## The lair keeps its own art (built in _ready), whatever the floor's variant is.
func _apply_floor_variant(_variant: RoomFloorVariant) -> void:
	pass
