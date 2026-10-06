# RangedAttack.gd — periodically fires a projectile at the player
class_name RangedAttack
extends AttackBehavior

@export var range: float = 250.0
@export var cooldown: float = 1.8
@export var projectile_scene: PackedScene
@export var projectile_damage: float = 1.0

var timer: float = 0.0

func update_cooldown(delta: float) -> void:
	timer = maxf(0.0, timer - delta)


func try_attack(enemy: EnemyBase, _delta: float) -> void:
	if timer > 0.0 or enemy.is_dying or enemy.action_state != "":
		return
	if not is_instance_valid(enemy.player) or not projectile_scene:
		return
	if enemy.global_position.distance_to(enemy.player.global_position) > range:
		return
	var dir := enemy.global_position.direction_to(enemy.player.global_position)
	enemy._update_facing_direction(dir)
	if enemy.begin_action("attack", "attack_" + enemy.facing_direction) < 0:
		return
	timer = cooldown
	var proj := projectile_scene.instantiate()
	proj.damage = projectile_damage
	enemy.get_parent().add_child(proj)
	proj.global_position = enemy.global_position
	if proj.has_method("launch"):
		proj.launch(dir, Vector2.ZERO)
