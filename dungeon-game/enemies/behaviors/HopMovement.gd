# HopMovement.gd — hops toward the player in short arcs, then sits still after landing
# (Drip Drop, Plunger Head). Predictable burst movement with a clear opening to hit it.
# If the enemy has an attack sheet it's used as the hop cycle (crouch, jump, air, land),
# spread over the hop; otherwise the run loop plays. The sprite is lifted along the arc.
class_name HopMovement
extends MovementBehavior

@export var hop_time: float = 0.35         # seconds in the air
@export var hop_speed: float = 120.0       # ground speed during a hop
@export var hop_height: float = 8.0        # px the sprite rises at the top of the arc
@export var rest_time: float = 0.8         # sits still this long after landing
@export var rest_variance: float = 0.25    # ± random share of rest_time, so a group doesn't sync

var _timer: float = -1.0
var _hopping: bool = false
var _dir: Vector2 = Vector2.ZERO
var _base_y: float = 0.0


func get_velocity(enemy: EnemyBase, delta: float) -> Vector2:
	if _timer < 0.0:  # first frame: start resting at a random point
		_base_y = enemy.sprite.position.y
		_timer = randf() * rest_time
	_timer -= delta
	if _hopping:
		var t := clampf(1.0 - _timer / hop_time, 0.0, 1.0)
		enemy.sprite.position.y = _base_y - sin(t * PI) * hop_height
		_show_hop_frame(enemy, t)
		if _timer <= 0.0:
			_land(enemy)
			return Vector2.ZERO
		return _dir * hop_speed
	if _timer <= 0.0 and enemy.player:
		_start_hop(enemy)
	return Vector2.ZERO


func _start_hop(enemy: EnemyBase) -> void:
	_hopping = true
	_timer = hop_time
	_dir = (enemy.get_player_aim_point() - enemy.global_position).normalized()
	enemy._update_facing_direction(_dir)
	if _has_hop_anim(enemy) and enemy.action_state == "":
		enemy.action_state = "hop"  # keeps EnemyBase from replaying the run loop


func _land(enemy: EnemyBase) -> void:
	_hopping = false
	_timer = rest_time * (1.0 + randf_range(-rest_variance, rest_variance))
	enemy.sprite.position.y = _base_y
	if enemy.action_state == "hop":
		enemy.action_state = ""


func _has_hop_anim(enemy: EnemyBase) -> bool:
	return enemy.has_action_anim()


func _show_hop_frame(enemy: EnemyBase, t: float) -> void:
	if enemy.action_state != "hop":
		return
	var anim := "attack_" + enemy.facing_direction
	var count := enemy.sprite.sprite_frames.get_frame_count(anim)
	LungeAttack._show_frame(enemy, anim, mini(int(t * count), count - 1))
