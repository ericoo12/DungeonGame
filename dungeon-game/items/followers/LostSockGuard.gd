## Lost Sock: trails behind you and covers your back. Enemy shots that hit it are soaked
## up (it gets visibly wetter); after `soak_to_wring` of them it wrings itself out - a
## spray of water shots at the nearest enemy - and is dry again.
class_name LostSockGuard
extends TrailFollower

@export var catch_radius: float = 9.0
@export var soak_to_wring: int = 3
@export var spray_count: int = 5
@export var spray_spread_deg: float = 40.0
## Spray damage compared to the player's shot damage.
@export var damage_ratio: float = 0.5
@export var spray_tint: Color = Color(0.55, 0.75, 1.0)
@export var wet_tint: Color = Color(0.55, 0.65, 0.95)

const SHOT_SCENE := preload("res://player/Projectile.tscn")

var _soaked: int = 0
var _catcher: Area2D


func setup(player: Player, delay: float) -> void:
	super.setup(player, delay)
	_catcher = Area2D.new()
	_catcher.collision_layer = 0
	_catcher.collision_mask = 64   # enemy projectiles
	_catcher.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = catch_radius
	shape.shape = circle
	_catcher.add_child(shape)
	add_child(_catcher)
	_catcher.area_entered.connect(_on_area_entered)


func _spawn_puddle() -> void:
	pass  # no trail


func _on_area_entered(area: Area2D) -> void:
	if not Orbital._is_enemy_shot(area):
		return
	if area.has_method("_land"):
		area.call("_land")
	else:
		area.queue_free()
	_soaked += 1
	_update_wetness()
	var squish := create_tween()
	squish.tween_property(sprite, "scale", sprite.scale * Vector2(1.25, 0.8), 0.06)
	squish.tween_property(sprite, "scale", sprite.scale, 0.12)
	if _soaked >= soak_to_wring:
		_wring_out.call_deferred()


func _update_wetness() -> void:
	var t := clampf(float(_soaked) / float(soak_to_wring), 0.0, 1.0)
	sprite.modulate = Color.WHITE.lerp(wet_tint, t)


func _wring_out() -> void:
	_soaked = 0
	_update_wetness()
	if not is_instance_valid(player_ref):
		return
	var target := _nearest_enemy()
	var aim := (target.global_position - global_position).normalized() if target else Vector2.RIGHT.rotated(randf() * TAU)
	for d in ShotPatternModifier.fan(aim, spray_count, spray_spread_deg / maxf(spray_count - 1, 1)):
		var shot: Projectile = SHOT_SCENE.instantiate()
		shot.damage = maxf(player_ref.get_effective_damage() * damage_ratio, 0.5)
		shot.knockback_strength = 40.0
		shot.lifetime = player_ref.projectile_range / maxf(player_ref.shot_speed, 0.05) * 0.8
		shot.speed_multiplier = player_ref.shot_speed
		shot.scale = Vector2.ONE * player_ref.projectile_size * 0.6
		shot.shooter = player_ref
		shot.modulate = spray_tint
		get_parent().add_child(shot)
		shot.global_position = global_position + sprite.position
		shot.launch(d, Vector2.ZERO)
	var shake := create_tween()
	for i in 4:
		shake.tween_property(sprite, "rotation", 0.35 if i % 2 == 0 else -0.35, 0.04)
	shake.tween_property(sprite, "rotation", 0.0, 0.04)


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := 260.0
	for node in get_parent().get_children():
		var e := node as EnemyBase
		if e == null or e.is_dying:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best
