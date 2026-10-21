## U-Bend: shot style whose projectiles fly out and come back (BoomerangProjectile).
## Replaces the current shot style like the laser does; still fans with Double/Quad,
## mirrors with Mirror Shot, splits with Split Seam and carries procs.
class_name BoomerangShotStyle
extends ShotStyleModifier

const SCENE := preload("res://items/projectiles/BoomerangProjectile.tscn")


func fire(player: Player, dir: Vector2, apply_momentum: bool) -> void:
	player.fire_projectile_scene(SCENE, dir, apply_momentum)
