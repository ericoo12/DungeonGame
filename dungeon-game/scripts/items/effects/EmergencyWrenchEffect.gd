## Emergency Wrench: throws a big, heavy shot in the direction the player is aiming.
## It deals `damage_ratio` x shot damage and stuns the first enemy it hits.
class_name EmergencyWrenchEffect
extends ActiveItemEffect

@export var damage_ratio: float = 4.0
@export var stun_duration: float = 2.0
@export var knockback: float = 300.0
@export var size: float = 1.8
@export var flight_time: float = 1.0
@export var tint: Color = Color(0.7, 0.72, 0.8)

const SHOT_SCENE := preload("res://scenes/player/Projectile.tscn")


func activate(player: Player) -> void:
	var stun := StunShotProc.new()
	stun.duration = stun_duration
	var shot: Projectile = SHOT_SCENE.instantiate()
	shot.damage = player.get_effective_damage() * damage_ratio
	shot.knockback_strength = knockback
	shot.lifetime = flight_time
	shot.speed_multiplier = player.shot_speed * 1.2
	shot.scale = Vector2.ONE * size
	shot.shooter = player
	shot.modulate = tint
	shot.procs = [stun]
	player.get_parent().add_child(shot)
	var dir := player.last_aim_dir if player.last_aim_dir != Vector2.ZERO else Vector2.DOWN
	shot.global_position = player.get_muzzle_position(dir)
	shot.launch(dir, Vector2.ZERO)
