## One-shot explosion. Plays the sheet and, on the big-burst frame, damages the player
## if their hurtbox is within `radius` (with knockback away from the blast).
## Reusable: enemy death_scene (FlyRed), bombs, items, ...
extends Node2D
class_name Explosion

@export_file("*.png") var sheet_path: String = "res://assets/sprites/effects/explosion.png"
@export var frame_count: int = 6
@export var fps: float = 14.0
@export var visual_scale: float = 0.8      # burst frame ends up ~48px across

@export_group("Damage")
@export var damages_player: bool = true
## Also hurts enemies in the radius (and chain-reacts other exploding enemies).
@export var damages_enemies: bool = true
@export var enemy_damage: float = 10.0       # HP (enemies use HP, the player uses hearts)
@export var radius: float = 22.0           # px from the blast centre to the player's hurtbox centre
@export var damage: float = 0.5            # hearts
@export var knockback_strength: float = 160.0
## Delay before the blast hurts: 2 frames at 14 fps = the big-burst frame. Also the
## tiny window the player gets to react.
@export var damage_delay: float = 0.14

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("projectiles")  # Dungeon clears this group on room change
	sprite.scale = Vector2.ONE * visual_scale
	sprite.sprite_frames = AnimSheetLoader.build_single_animation(sheet_path, frame_count, fps, false, "explode")
	sprite.play("explode")
	sprite.animation_finished.connect(queue_free)
	# connect (not await): if the explosion is freed first, the callback just never runs
	get_tree().create_timer(damage_delay, false).timeout.connect(_detonate)


func _detonate() -> void:
	if damages_player:
		_damage_player()
	if damages_enemies:
		_damage_enemies()


func _damage_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	var target := player.get_hurtbox_center()
	if global_position.distance_to(target) <= radius:
		player.take_damage(damage, target - global_position, knockback_strength)


## Every enemy body touching the blast circle (physics layer 3 = enemies).
func _damage_enemies() -> void:
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 1 << 2
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var enemy := hit.collider as EnemyBase
		if enemy and not enemy.is_dying:
			enemy.take_damage(enemy_damage, enemy.global_position - global_position, knockback_strength)
