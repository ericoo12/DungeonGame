# RollAttack.gd — the hairball: sits still, then curls up and rolls at the player for
# about the length of a room, bouncing off walls, obstacles and other enemies.
# Windup (shakes in place, telegraph) -> roll along the locked direction -> stop, recover.
# Damage is the enemy's normal contact damage while it rolls into the player.
# Uses the attack sheet as the roll cycle (frames advance with the distance rolled).
# Per-enemy state lives here; EnemyBase duplicates the resource for every enemy.
class_name RollAttack
extends AttackBehavior

## Starts a roll when the player is closer than this (px). 400 = anywhere in a room.
@export var trigger_range: float = 400.0
@export var require_line_of_sight: bool = true
## Seconds between rolls (counted from when a roll ends).
@export var cooldown: float = 2.2
## First roll waits at least this long after the hairball appears.
@export var first_delay: float = 1.0

@export_group("Roll")
@export var windup: float = 0.6               # shaking in place: the player's cue to move
@export var roll_speed: float = 230.0
@export var roll_distance: float = 380.0      # about the length of a room
@export var max_bounces: int = 4
## Speed kept after each bounce.
@export_range(0.0, 1.0) var bounce_keep: float = 0.85
@export var recover: float = 0.8              # dizzy pause afterwards
## px rolled per roll frame (the roll cycle advances with distance, not time).
@export var px_per_frame: float = 9.0
## Can't be knocked around or interrupted by hits while rolling.
@export var armored_while_rolling: bool = true

var timer: float = 0.0
var _started: bool = false


func try_attack(enemy: EnemyBase, delta: float) -> void:
	if not _started:
		_started = true
		timer = first_delay
	if timer > 0.0:
		timer -= delta
		return
	if enemy.player == null:
		return
	var to_player := enemy.get_player_aim_point() - enemy.global_position
	if to_player.length() > trigger_range:
		return
	if require_line_of_sight:
		var from := enemy.global_position
		var query := PhysicsRayQueryParameters2D.create(from, from + to_player, 1, [enemy.get_rid()])
		if not enemy.get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			return
	timer = INF  # paused until the roll finishes
	_roll(enemy, to_player.normalized())


func _roll(enemy: EnemyBase, dir: Vector2) -> void:
	enemy.action_state = "attack"
	enemy._update_facing_direction(dir)
	enemy.forced_velocity_active = true
	enemy.forced_velocity = Vector2.ZERO
	var anim := "attack_" + enemy.facing_direction
	var start_x := enemy.sprite.position.x

	# Windup: curl up (first roll frame) and shake.
	LungeAttack._show_frame(enemy, anim, 0)
	var shake := enemy.create_tween().set_loops(int(windup / 0.08))
	shake.tween_property(enemy.sprite, "position:x", start_x + 1.5, 0.04)
	shake.tween_property(enemy.sprite, "position:x", start_x - 1.5, 0.04)
	var ok := await _wait(enemy, windup)
	shake.kill()
	if is_instance_valid(enemy):
		enemy.sprite.position.x = start_x
	if not ok:
		_finish(enemy)
		return

	# Roll: re-aim at the player once more (the windup was the warning), then go.
	var aim := enemy.get_player_aim_point() - enemy.global_position
	if aim.length() > 1.0:
		dir = aim.normalized()
	var was_immune := enemy.knockback_immune
	if armored_while_rolling:
		enemy.knockback_immune = true
		enemy.super_armor = true
	var speed := roll_speed
	var rolled := 0.0
	var bounces := 0
	var frames := enemy.sprite.sprite_frames.get_frame_count(anim)
	while rolled < roll_distance and bounces <= max_bounces:
		enemy.forced_velocity = dir * speed
		enemy.sprite.flip_h = (dir.x > 0.0) != enemy.side_view_faces_right
		enemy.sprite.frame = int(rolled / px_per_frame) % maxi(frames, 1)
		await enemy.get_tree().physics_frame
		if not is_instance_valid(enemy) or enemy.is_dying:
			return
		if enemy.action_state != "attack":
			break
		rolled += speed * enemy.get_physics_process_delta_time()
		# Bounce off whatever move_and_slide() ran into this frame.
		for i in enemy.get_slide_collision_count():
			var normal := enemy.get_slide_collision(i).get_normal()
			if dir.dot(normal) < 0.0:
				dir = dir.bounce(normal).normalized()
				speed *= bounce_keep
				bounces += 1
				break
	enemy.knockback_immune = was_immune
	enemy.super_armor = false

	# Recover: stopped and dizzy on the last roll frame.
	enemy.forced_velocity = Vector2.ZERO
	await _wait(enemy, recover)
	_finish(enemy)


func _wait(enemy: EnemyBase, seconds: float) -> bool:
	await enemy.get_tree().create_timer(seconds, false).timeout
	if not is_instance_valid(enemy) or enemy.is_dying:
		return false
	return enemy.action_state == "attack"


func _finish(enemy: EnemyBase) -> void:
	timer = cooldown
	if not is_instance_valid(enemy):
		return
	enemy.forced_velocity_active = false
	enemy.forced_velocity = Vector2.ZERO
	enemy.super_armor = false
	if enemy.action_state == "attack":
		enemy.action_state = ""
