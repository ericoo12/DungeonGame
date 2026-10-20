## Sewer Gas: chance per shot to fill the enemy with gas: it explodes when it dies,
## hurting other enemies nearby (never the player).
class_name GasShotProc
extends ShotProcEffect

@export var explosion_damage_ratio: float = 2.0   # x the player's shot damage
@export var explosion_radius: float = 30.0
@export var tint: Color = Color(0.7, 0.85, 0.35)


func decorate_projectile(projectile: Node) -> void:
	if projectile is CanvasItem:
		projectile.modulate = tint


func on_hit(target: Node, player: Player) -> void:
	if not (target is EnemyBase) or not is_instance_valid(player):
		return
	GasStatus.apply(target, player.get_effective_damage() * explosion_damage_ratio, explosion_radius)


func get_stat_text() -> String:
	return "%d%% chance to make enemies explode on death" % roundi(get_chance() * 100.0) + luck_text()
