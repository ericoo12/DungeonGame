## Follows the player's recorded past positions at a fixed time delay (not an
## instant offset), giving a genuine "trailing a few paces behind" feel rather
## than a rigid formation. Periodically drops a damaging Puddle in its wake.
extends Node2D
class_name TrailFollower

@export var trail_delay: float = 0.4
@export var bob_height: float = 3.0
@export var bob_speed: float = 4.0
@export var min_distance_from_player: float = 20.0
@export var follow_speed_ratio: float = 0.9

@export var puddle_interval: float = 0.1
@export var puddle_damage: float = 2.0
@export var puddle_lifetime: float = 1.5
@export var puddle_radius: float = 10.0
@export var puddle_offset: Vector2 = Vector2(0, 16)

const PUDDLE_SCENE := preload("res://scenes/items/trail_follower/Puddle.tscn")

var player_ref: Player
var bob_time: float = 0.0
var puddle_timer: float = 0.0

@onready var sprite: Node2D = $Sprite2D


func setup(player: Player, delay: float) -> void:
	player_ref = player
	trail_delay = delay
	global_position = player.global_position


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player_ref):
		queue_free()
		return

	var raw_target: Vector2 = player_ref.get_trailing_position(trail_delay, global_position)
	var to_target: Vector2 = raw_target - player_ref.global_position
	var dist: float = to_target.length()

	var clamped_target: Vector2 = raw_target
	if dist < min_distance_from_player and dist > 0.001:
		clamped_target = player_ref.global_position + to_target.normalized() * min_distance_from_player

	var follow_speed: float = player_ref.move_speed * follow_speed_ratio
	global_position = global_position.move_toward(clamped_target, follow_speed * delta)

	bob_time += delta * bob_speed
	sprite.position.y = -abs(sin(bob_time)) * bob_height

	puddle_timer -= delta
	if puddle_timer <= 0.0:
		puddle_timer = puddle_interval
		_spawn_puddle()


func _spawn_puddle() -> void:
	var puddle: Puddle = PUDDLE_SCENE.instantiate()
	var ground_layer := get_tree().get_first_node_in_group("ground_effects")
	var target_parent: Node = ground_layer if ground_layer else get_parent()
	target_parent.add_child(puddle)
	puddle.global_position = global_position + puddle_offset
	puddle.setup(puddle_damage, puddle_lifetime, puddle_radius)
