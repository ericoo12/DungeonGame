extends RoomController
class_name FinalBossArena

## The final boss's room (Doktor Mugg): a 4x room-sized arena with its own walls
## (Perimeter) and blocks. Everything the boss AI needs from its room lives here, so the
## normal rooms (RoomBase) are untouched.

## Local room rectangle in gameplay units. Keep it aligned with the arena walls.
@export var arena_bounds := Rect2(-216.0, -112.0, 432.0, 224.0)
const SIGHT_BLOCKER_MASK: int = 1 << 9


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


func _apply_floor_variant(variant: RoomFloorVariant) -> void:
	if not variant or not variant.texture:
		return
	var floor_patch := AtlasTexture.new()
	floor_patch.atlas = variant.texture
	floor_patch.region = Rect2(80, 48, 64, 48)
	$QuarterArt/FloorFill.texture = floor_patch
	for name in ["TopLeft", "TopRight", "BottomLeft", "BottomRight"]:
		var atlas := AtlasTexture.new()
		atlas.atlas = variant.texture
		atlas.region = Rect2(10, 0, 202, 112)
		get_node("QuarterArt/" + name + "/Art").texture = atlas
