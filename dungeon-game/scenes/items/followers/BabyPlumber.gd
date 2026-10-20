## Baby Plumber: follows the player and throws a short-range wrench at the nearest enemy
## within `attack_range` every `cooldown` seconds, by itself (not tied to your shots).
class_name BabyPlumber
extends TrailFollower

@export var attack_range: float = 95.0
@export var cooldown: float = 1.1
@export var damage_ratio: float = 0.7
@export var shot_range: float = 0.45        # flight time in seconds (short)
@export var shot_size: float = 0.9
@export var knockback: float = 60.0
@export var shot_tint: Color = Color(0.75, 0.78, 0.85)

const SHOT_SCENE := preload("res://scenes/player/Projectile.tscn")

var _cooldown_left: float = 0.5


func _spawn_puddle() -> void:
	pass


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_instance_valid(player_ref):
		return
	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return
	var target := _nearest_enemy()
	if target == null:
		return
	_cooldown_left = cooldown
	_throw_at(target)


func _nearest_enemy() -> EnemyBase:
	var best: EnemyBase = null
	var best_d := attack_range
	for node in get_parent().get_children():
		var e := node as EnemyBase
		if e == null or e.is_dying or e.spawn_timer > 0.0:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _throw_at(target: EnemyBase) -> void:
	var shot: Projectile = SHOT_SCENE.instantiate()
	shot.damage = maxf(player_ref.get_effective_damage() * damage_ratio, 0.5)
	shot.knockback_strength = knockback
	shot.lifetime = shot_range
	shot.speed_multiplier = 1.4
	shot.scale = Vector2.ONE * shot_size
	shot.shooter = player_ref
	shot.modulate = shot_tint
	get_parent().add_child(shot)
	shot.global_position = global_position + sprite.position
	shot.launch((target.global_position - shot.global_position).normalized(), Vector2.ZERO)
