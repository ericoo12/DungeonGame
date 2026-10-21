## Chance per shot to poison the enemy hit (Septic Infection). Damage per second scales
## with the player's current damage, so it stays useful as damage goes up.
class_name PoisonShotProc
extends ShotProcEffect

## Poison damage per second, as a share of the player's shot damage.
@export var dps_ratio: float = 0.6
@export var duration: float = 3.0
@export var tint: Color = Color(0.55, 1.0, 0.35)


func decorate_projectile(projectile: Node) -> void:
	if projectile is CanvasItem:
		projectile.modulate = tint


func on_hit(target: Node, player: Player) -> void:
	var dmg: float = player.get_effective_damage() if is_instance_valid(player) else 3.5
	PoisonStatus.apply(target, dmg * dps_ratio, duration)


func get_stat_text() -> String:
	return "%d%% chance to poison for %ss" % [roundi(get_chance() * 100.0), str(duration)] + luck_text()
