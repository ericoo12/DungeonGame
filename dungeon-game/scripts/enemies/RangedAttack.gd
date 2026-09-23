# RangedAttack.gd — periodically fires a projectile at the player
class_name RangedAttack
extends AttackBehavior

@export var range: float = 250.0
@export var cooldown: float = 1.8
@export var projectile_scene: PackedScene
@export var projectile_damage: float = 1.0

var timer: float = 0.0

func try_attack(enemy: EnemyBase, delta: float) -> void:
	if timer > 0.0:
		timer -= delta
		return
	if not enemy.player or not projectile_scene:
		return
	if enemy.global_position.distance_to(enemy.player.global_position) > range:
		return

	timer = cooldown
	var dir: Vector2 = (enemy.player.global_position - enemy.global_position).normalized()
	var proj := projectile_scene.instantiate()
	enemy.get_parent().add_child(proj)
	proj.global_position = enemy.global_position
	proj.damage = projectile_damage
	if proj.has_method("launch"):
		proj.launch(dir, Vector2.ZERO)
