# RangedAttack.gd — periodically fires a projectile at the player (turrets, spitters)
class_name RangedAttack
extends AttackBehavior

@export var range: float = 250.0
@export var cooldown: float = 1.8
@export var projectile_scene: PackedScene
@export var projectile_damage: float = 1.0
## Random delay (min, max) before the FIRST shot once the player is in range: gives the
## player a moment after entering, and de-syncs multiple shooters in one room.
@export var first_shot_delay: Vector2 = Vector2(0.4, 1.2)
## Only fire when nothing solid (walls, obstacles, locked doors) is between the shooter
## and the player, instead of wasting shots into crates.
@export var require_line_of_sight: bool = true
## If the enemy has an "attack_<dir>" animation it's played, and the projectile is
## released this many seconds in (sync it to the frame where the shot leaves).
## 0 = fire instantly, no animation.
@export var attack_windup: float = 0.2

# Per-enemy state (EnemyBase duplicates this resource for every enemy).
var timer: float = 0.0
var _armed: bool = false


func try_attack(enemy: EnemyBase, delta: float) -> void:
	if timer > 0.0:
		timer -= delta
		return
	if not enemy.player or not projectile_scene:
		return

	var target := enemy.get_player_aim_point()
	if enemy.global_position.distance_to(target) > range:
		return
	if not _armed:
		_armed = true
		timer = randf_range(first_shot_delay.x, first_shot_delay.y)
		return
	if require_line_of_sight and not _has_line_of_sight(enemy, target):
		return  # hold fire, try again next frame

	timer = cooldown
	_attack(enemy)


func _attack(enemy: EnemyBase) -> void:
	var anim := "attack_" + enemy.facing_direction
	if attack_windup <= 0.0 or not enemy.sprite.sprite_frames.has_animation(anim):
		_fire(enemy)
		return

	enemy.action_state = "attack"  # keeps EnemyBase from switching back to the run/idle loop
	enemy.sprite.play(anim)
	await enemy.get_tree().create_timer(attack_windup, false).timeout  # pauses with the game
	if not is_instance_valid(enemy) or enemy.is_dying:
		return
	_fire(enemy)
	if enemy.sprite.animation == anim and enemy.sprite.is_playing():
		await enemy.sprite.animation_finished
	if is_instance_valid(enemy) and enemy.action_state == "attack":
		enemy.action_state = ""


## Aims at the moment of release, so the windup doesn't make it shoot where you were.
func _fire(enemy: EnemyBase) -> void:
	var dir: Vector2 = (enemy.get_player_aim_point() - enemy.global_position).normalized()
	var proj := projectile_scene.instantiate()
	enemy.get_parent().add_child(proj)
	proj.global_position = enemy.global_position
	proj.damage = projectile_damage
	if proj.has_method("launch"):
		proj.launch(dir, Vector2.ZERO)


## Ray on the world layer (1): walls, obstacles and door blockers all live there.
func _has_line_of_sight(enemy: EnemyBase, target: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(enemy.global_position, target, 1, [enemy.get_rid()])
	return enemy.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
