## Wet Floor Sign: chance per shot to make the enemy slip: it slides along the way it
## was moving (or away from the shot if it was standing still) and is briefly stunned,
## so it can bump into walls, obstacles and other enemies. Bosses only slide a little.
class_name SlipShotProc
extends ShotProcEffect

@export var slide_speed: float = 330.0   # ~65 px slide
@export var boss_slide_speed: float = 60.0
@export var stun_time: float = 0.6
@export var tint: Color = Color(1, 0.86, 0.3)


func decorate_projectile(projectile: Node) -> void:
	if projectile is CanvasItem:
		projectile.modulate = tint


func on_hit(target: Node, player: Player) -> void:
	var enemy := target as EnemyBase
	if enemy == null or enemy.is_dying or enemy.knockback_immune:
		return
	var dir := enemy.velocity.normalized()
	if dir == Vector2.ZERO and is_instance_valid(player):
		dir = (enemy.global_position - player.global_position).normalized()
	enemy.knockback_velocity = dir * (boss_slide_speed if enemy.is_boss else slide_speed)
	enemy.apply_stun(stun_time)


func get_stat_text() -> String:
	return "%d%% chance to make enemies slip" % roundi(get_chance() * 100.0) + luck_text()
