## A follower (same trailing movement as Nosebleed, no trail) that fires a shot in the
## player's aim direction when the player shoots. Used by Drain Fly (every shot, weak)
## and Lost Sock (sometimes, a weaker copy with your shot effects).
## Shots use the player's range / shot speed / size, scaled by the ratios below.
class_name ShootingFollower
extends TrailFollower

## Chance to fire each time the player shoots (1 = every shot).
@export_range(0.0, 1.0) var fire_chance: float = 1.0
@export var damage_ratio: float = 0.35
@export var size_ratio: float = 0.6
@export var knockback: float = 20.0
## Also roll the player's shot effects (poison, slow, ...) for this shot.
@export var copy_procs: bool = false
## Fire the opposite way of the player's shot (Lost Sock covers your back).
@export var fire_backwards: bool = false
@export var shot_tint: Color = Color.WHITE
## Sprite sheet animation (Sprite2D.hframes > 1).
@export var anim_fps: float = 14.0

const SHOT_SCENE := preload("res://scenes/player/Projectile.tscn")

var _anim_time: float = 0.0


func setup(player: Player, delay: float) -> void:
	super.setup(player, delay)
	if not player.shot_fired.is_connected(_on_player_shot):
		player.shot_fired.connect(_on_player_shot)


func _process(delta: float) -> void:
	var s := sprite as Sprite2D
	if s and s.hframes > 1:
		_anim_time += delta * anim_fps
		s.frame = int(_anim_time) % s.hframes


func _spawn_puddle() -> void:
	pass  # no trail


func _on_player_shot(direction: Vector2) -> void:
	if not is_instance_valid(player_ref) or not is_inside_tree() or randf() > fire_chance:
		return
	var shot: Projectile = SHOT_SCENE.instantiate()
	shot.damage = maxf(player_ref.get_effective_damage() * damage_ratio, 0.5)
	shot.knockback_strength = knockback
	shot.lifetime = player_ref.projectile_range
	shot.speed_multiplier = player_ref.shot_speed
	shot.scale = Vector2.ONE * player_ref.projectile_size * size_ratio
	shot.shooter = player_ref
	shot.modulate = shot_tint
	if copy_procs:
		shot.procs = player_ref.roll_shot_procs()
		for proc in shot.procs:
			proc.decorate_projectile(shot)
	get_parent().add_child(shot)
	shot.global_position = global_position + sprite.position
	shot.launch(-direction if fire_backwards else direction, Vector2.ZERO)
