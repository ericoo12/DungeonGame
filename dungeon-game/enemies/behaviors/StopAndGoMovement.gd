# StopAndGoMovement.gd — Wet Sock: chases (using `chase`, e.g. a SwarmChaseMovement that
# paths around obstacles), and every so often stops to shake itself off for a moment.
# The shake plays the attack sheet if it has one, plus a little wiggle, and (if
# spray_scene is set) flings a ring of water drops in every direction mid-shake.
class_name StopAndGoMovement
extends MovementBehavior

@export var chase: MovementBehavior
@export var move_time: Vector2 = Vector2(2.0, 3.5)   # random seconds of chasing
@export var stop_time: float = 0.9                   # seconds shaking in place

@export_group("Spray")
## Shot flung out while shaking. Empty = the shake is just for show.
@export var spray_scene: PackedScene
@export var spray_count: int = 6
@export var spray_speed: float = 75.0
@export var spray_damage: float = 0.5
## Seconds into the shake when the drops fly (gives you a tell to back off).
@export var spray_delay: float = 0.4
@export_group("")

var _timer: float = -1.0
var _stopped: bool = false
var _base_x: float = 0.0
var _sprayed: bool = false


func get_velocity(enemy: EnemyBase, delta: float) -> Vector2:
	if _timer < 0.0:
		_base_x = enemy.sprite.position.x
		if chase:
			chase = chase.duplicate()  # own copy: wander state isn't shared between socks
		_timer = randf_range(move_time.x, move_time.y)
	_timer -= delta
	if _stopped:
		enemy.sprite.position.x = _base_x + sin(_timer * 50.0) * 1.2  # shake
		if not _sprayed and stop_time - _timer >= spray_delay:
			_sprayed = true
			_spray(enemy)
		if _timer <= 0.0:
			_stopped = false
			enemy.sprite.position.x = _base_x
			_timer = randf_range(move_time.x, move_time.y)
			if enemy.action_state == "shake":
				enemy.action_state = ""
		return Vector2.ZERO
	if _timer <= 0.0:
		_stopped = true
		_sprayed = false
		_timer = stop_time
		if enemy.action_state == "" and enemy.has_action_anim():
			enemy.action_state = "shake"
			enemy.sprite.play("attack_" + enemy.facing_direction)
		return Vector2.ZERO
	return chase.get_velocity(enemy, delta) if chase else Vector2.ZERO


## A ring of drops, evenly spaced with a random twist so the gaps move around.
func _spray(enemy: EnemyBase) -> void:
	if spray_scene == null or spray_count <= 0:
		return
	var twist := randf() * TAU
	for i in spray_count:
		var dir := Vector2.RIGHT.rotated(twist + TAU * i / spray_count)
		var proj := spray_scene.instantiate()
		proj.damage = spray_damage
		if spray_speed > 0.0 and "speed" in proj:
			proj.speed = spray_speed  # before add_child: the shot sets its range from it
		enemy.get_parent().add_child(proj)
		proj.global_position = enemy.global_position
		if proj.has_method("launch"):
			proj.launch(dir, Vector2.ZERO)
