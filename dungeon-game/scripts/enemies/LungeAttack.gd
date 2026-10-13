# LungeAttack.gd — strikes at the player when they're close AND in front of the enemy
# (vision cone around EnemyBase.heading: front + both sides, never behind) with a clear
# line. Coil (windup, telegraph) -> strike along the locked direction -> recover.
# Damage is the enemy's normal contact damage while it rams the player.
# Per-enemy state lives here; EnemyBase duplicates the resource for every enemy.
class_name LungeAttack
extends AttackBehavior

@export var lunge_range: float = 56.0          # px to the player's hurtbox
## Half-angle of the vision cone. 110 = front and both sides (220° total); the 140°
## behind the enemy is blind.
@export var vision_half_angle_deg: float = 110.0
@export var require_line_of_sight: bool = true
@export var cooldown: float = 2.0

@export_group("Strike")
@export var windup: float = 0.35               # coiled and still: the player's cue to dodge
@export var lunge_speed: float = 220.0
@export var lunge_duration: float = 0.25       # 220 * 0.25 = ~55 px strike
@export var recover: float = 0.4               # vulnerable pause afterwards

## Attack sheet frames used per phase (snake: 0 coil, 1-2 strike, 3 recoil).
@export var coil_frame: int = 0
@export var strike_frames: Vector2i = Vector2i(1, 2)
@export var recover_frame: int = 3

var timer: float = 0.0


func try_attack(enemy: EnemyBase, delta: float) -> void:
	if timer > 0.0:
		timer -= delta
		return
	if enemy.player == null:
		return
	var to_player := enemy.get_player_aim_point() - enemy.global_position
	if to_player.length() > lunge_range:
		return
	if not can_see(enemy, to_player):
		return
	timer = cooldown
	_lunge(enemy, to_player.normalized())


## In the vision cone (not behind) and nothing solid in between.
func can_see(enemy: EnemyBase, to_player: Vector2) -> bool:
	if absf(rad_to_deg(enemy.heading.angle_to(to_player))) > vision_half_angle_deg:
		return false
	if require_line_of_sight:
		var from := enemy.global_position
		var query := PhysicsRayQueryParameters2D.create(from, from + to_player, 1, [enemy.get_rid()])
		if not enemy.get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true


func _lunge(enemy: EnemyBase, dir: Vector2) -> void:
	enemy.action_state = "attack"
	enemy._update_facing_direction(dir)  # first, so the up/down/side lunge art is picked
	var anim := "attack_" + enemy.facing_direction
	enemy.forced_velocity_active = true

	# Coil: stand still, show the coil frame.
	enemy.forced_velocity = Vector2.ZERO
	_show_frame(enemy, anim, coil_frame)
	if not await _wait(enemy, windup):
		return

	# Strike along the direction locked at the start of the windup (dodgeable).
	enemy.forced_velocity = dir * lunge_speed
	_show_frame(enemy, anim, strike_frames.x)
	if not await _wait(enemy, lunge_duration * 0.5):
		return
	_show_frame(enemy, anim, strike_frames.y)
	if not await _wait(enemy, lunge_duration * 0.5):
		return

	# Recover: stop, recoil frame.
	enemy.forced_velocity = Vector2.ZERO
	_show_frame(enemy, anim, recover_frame)
	if not await _wait(enemy, recover):
		return
	_finish(enemy)


## Waits (pauses with the game). False if the lunge was interrupted (death, damage
## animation took over) — the state is cleaned up then.
func _wait(enemy: EnemyBase, seconds: float) -> bool:
	await enemy.get_tree().create_timer(seconds, false).timeout
	if not is_instance_valid(enemy) or enemy.is_dying:
		return false
	if enemy.action_state != "attack":
		enemy.forced_velocity_active = false
		return false
	return true


func _finish(enemy: EnemyBase) -> void:
	enemy.forced_velocity_active = false
	enemy.forced_velocity = Vector2.ZERO
	if enemy.action_state == "attack":
		enemy.action_state = ""


static func _show_frame(enemy: EnemyBase, anim: String, frame: int) -> void:
	if not enemy.sprite.sprite_frames.has_animation(anim):
		return
	if enemy.sprite.animation != anim:
		enemy.sprite.play(anim)
	enemy.sprite.pause()
	enemy.sprite.frame = clampi(frame, 0, enemy.sprite.sprite_frames.get_frame_count(anim) - 1)
