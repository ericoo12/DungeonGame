## ShotStyleModifier: replaces the player's shot with an instant hitscan laser
## (raycast + one-shot damage) instead of a spawned Projectile. Equipped via
## Item.shot_style — see ItemBase.gd family for how items grant this.
class_name LaserShotStyle
extends ShotStyleModifier

# Base values, as tuned on the resource itself.
@export var base_max_range: float = 300.0
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


func fire(player: Player, dir: Vector2, apply_momentum: bool) -> void:
	# Move the player's shared LaserRay out to the muzzle point and cast along
	# the aim direction — this ray is reused across shots, not per-instance.
	var marker_offset: Vector2 = player.weapon_marker.position
	player.laser_ray.position = marker_offset + dir * start_offset
	player.laser_ray.target_position = dir * max_range
	player.laser_ray.force_raycast_update()


	var start_point: Vector2 = player.weapon_marker.global_position + dir * start_offset
	var end_point: Vector2 = start_point + dir * max_range

	if player.laser_ray.is_colliding():
			end_point = player.laser_ray.get_collision_point()
			var collider: Object = player.laser_ray.get_collider()
			if collider and collider.has_method("take_damage"):
				collider.take_damage(player.get_effective_damage(), dir, player.projectile_knockback)

	# Purely cosmetic — the visual beam is spawned after damage is already
	# resolved above, since this is a hitscan (instant), not a travelling shot.
	var beam: LaserBeamVisual = BEAM_VISUAL_SCENE.instantiate()
	player.add_child(beam)
	beam.setup(start_point, end_point, beam_width, visual_duration)
