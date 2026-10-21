## Emergency Flush: shoves every enemy and enemy projectile away from the player.
## Enemies that slam into a wall or obstacle while flying take slam_damage (once).
## Knockback-immune enemies (pipes, bins) don't move; bosses get a much smaller push.
class_name EmergencyFlushEffect
extends ActiveItemEffect

@export var push_strength: float = 450.0
@export var boss_push_strength: float = 120.0
@export var slam_damage: float = 8.0
## How long after the push a wall hit still counts as a slam.
@export var slam_window: float = 0.6
@export var projectile_min_speed: float = 160.0


func activate(player: Player) -> void:
	var origin := player.global_position
	var container := player.get_parent()
	if container:
		for node in container.get_children():
			var enemy := node as EnemyBase
			if enemy == null or enemy.is_dying or enemy.knockback_immune:
				continue
			var away := enemy.global_position - origin
			away = away.normalized() if away.length() > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)
			enemy.knockback_velocity = away * (boss_push_strength if enemy.is_boss else push_strength)
			if not enemy.is_boss and slam_damage > 0.0:
				FlushSlam.attach(enemy, slam_damage, slam_window)

	for proj in player.get_tree().get_nodes_in_group("projectiles"):
		if proj is Projectile or not ("velocity" in proj):
			continue  # leave the player's own shots alone
		var away: Vector2 = proj.global_position - origin
		away = away.normalized() if away.length() > 0.01 else Vector2.UP
		var speed: float = maxf(proj.velocity.length(), projectile_min_speed)
		proj.velocity = away * speed
