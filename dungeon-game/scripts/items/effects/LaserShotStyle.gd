## ShotStyleModifier: replaces the player's shot with an instant hitscan laser
## (raycast + one-shot damage) instead of a spawned Projectile. Equipped via
## Item.shot_style — see ItemBase.gd family for how items grant this.
class_name LaserShotStyle
extends ShotStyleModifier

# Base values, as tuned on the resource itself.
@export var base_max_range: float = 3000.0
@export var base_beam_width: float = 6.0
@export var visual_duration: float = 0.2
@export var start_offset: float = 2.00

# Live values, recalculated by apply_player_stats() from the base values above
# times the player's current range/size bonuses (both default to a 1.0
# multiplier, so an unmodified player gets exactly the base numbers).
var max_range: float
var beam_width: float

const BEAM_VISUAL_SCENE := preload("res://scenes/items/laserbeam/LaserBeamVisual.tscn")


func apply_player_stats(player: Player) -> void:
	max_range = base_max_range * player.projectile_range
	beam_width = base_beam_width * player.projectile_size


## Physics layers the laser cares about: layer 1 = walls + obstacles and layer 9 = the
## final arena's projectile blockers (stop the beam), layer 3 = enemy bodies (pierced:
## every enemy on the line gets hit once).
const STOP_MASK := 1 | (1 << 8)
const ENEMY_MASK := 4
const MAX_PIERCE := 32


func fire(player: Player, dir: Vector2, apply_momentum: bool) -> void:
	var start_point: Vector2 = player.get_muzzle_position(dir) + dir * start_offset
	var space := player.get_world_2d().direct_space_state

	# Luck-scaled shot effects (e.g. slow) roll per laser shot, same as projectiles.
	var triggered_procs := player.roll_shot_procs()
	var damage := player.get_effective_damage()

	# 1. Where the beam stops: first wall or obstacle. Obstacles still take the hit
	#    (breakables count it like any other shot).
	var end_point: Vector2 = start_point + dir * max_range
	var stop_query := PhysicsRayQueryParameters2D.create(start_point, end_point, STOP_MASK, [player.get_rid()])
	var stop_hit := space.intersect_ray(stop_query)
	if stop_hit:
		end_point = stop_hit.position
		var blocker: Object = stop_hit.collider
		if blocker and blocker.has_method("take_damage"):
			blocker.take_damage(damage, dir, player.projectile_knockback)

	# 2. Pierce: every enemy between the muzzle and that point gets hit once. Each ray
	#    excludes the enemies already hit, so it finds the next one along the line.
	var exclude: Array[RID] = [player.get_rid()]
	for _i in MAX_PIERCE:
		var query := PhysicsRayQueryParameters2D.create(start_point, end_point, ENEMY_MASK, exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		exclude.append(hit.rid)
		var enemy: Object = hit.collider
		if enemy and enemy.has_method("take_damage"):
			enemy.take_damage(damage, dir, player.projectile_knockback)
			for proc in triggered_procs:
				proc.on_hit(enemy, player)

	# Purely cosmetic — the visual beam is spawned after damage is alreadys
	# resolved above, since this is a hitscan (instant), not a travelling shot.
	var beam: LaserBeamVisual = BEAM_VISUAL_SCENE.instantiate()
	player.add_child(beam)
	beam.setup(start_point, end_point, beam_width, visual_duration,
		dir, max_range, STOP_MASK, [player.get_rid()])  # visual also only stops at walls/obstacles
	for proc in triggered_procs:
		proc.decorate_projectile(beam)  # tints the beam, so a proc'd shot is visible
