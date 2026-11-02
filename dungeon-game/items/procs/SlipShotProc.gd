## Wet Floor Sign: chance per shot to make the enemy slip. It always slides AWAY from
## you (a little to one side, at random) and is briefly stunned and harmless while it
## slides, so it can bump into walls, obstacles and other enemies but never into you.
## Bosses only slide a little.
class_name SlipShotProc
extends ShotProcEffect

@export var slide_speed: float = 260.0   # ~40 px slide
@export var boss_slide_speed: float = 60.0
@export var stun_time: float = 0.6
## Random sideways angle added to "straight away from the player" (degrees, either side).
@export var spread_deg: float = 35.0
@export var tint: Color = Color(1, 0.86, 0.3)


func decorate_projectile(projectile: Node) -> void:
	if projectile is CanvasItem:
		projectile.modulate = tint


func on_hit(target: Node, player: Player) -> void:
	var enemy := target as EnemyBase
	if enemy == null or enemy.is_dying or enemy.knockback_immune:
		return
	var dir := Vector2.ZERO
	if is_instance_valid(player):
		dir = (enemy.global_position - player.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.from_angle(randf() * TAU)
	dir = dir.rotated(deg_to_rad(randf_range(-spread_deg, spread_deg)))
	enemy.knockback_velocity = dir * (boss_slide_speed if enemy.is_boss else slide_speed)
	enemy.apply_stun(stun_time)
	if not enemy.is_boss:
		enemy.set_meta(&"harmless_until_ms", Time.get_ticks_msec() + int(stun_time * 1000.0))


func get_stat_text() -> String:
	return "%d%% chance to make enemies slip" % roundi(get_chance() * 100.0) + luck_text()
