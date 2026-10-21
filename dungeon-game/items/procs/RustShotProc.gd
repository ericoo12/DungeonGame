## Rusty Water: chance per shot to rust the enemy: slowed to `slow_factor` speed and
## takes `knockback_mult` x knockback for `duration` seconds.
class_name RustShotProc
extends ShotProcEffect

@export var slow_factor: float = 0.7
@export var knockback_mult: float = 1.6
@export var duration: float = 3.0
@export var tint: Color = Color(0.8, 0.5, 0.3)


func decorate_projectile(projectile: Node) -> void:
	if projectile is CanvasItem:
		projectile.modulate = tint


func on_hit(target: Node, _player: Player) -> void:
	if target.has_method("apply_rust"):
		target.apply_rust(slow_factor, knockback_mult, duration)


func get_stat_text() -> String:
	return "%d%% chance to rust (slower, more knockback)" % roundi(get_chance() * 100.0) + luck_text()
