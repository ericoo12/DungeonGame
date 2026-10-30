## Toilet Brush boss.
## Moves around the player at a preferred distance (strafing, switching direction now
## and then) and picks a random attack each time its cooldown runs out, weighted by
## distance and never the same attack twice in a row:
##   Lunge     - short wind-up (flashes), then dashes at where you are. Phase 2: two in a row.
##   Spit fan  - 3 shots in a fan (phase 2: 5).
##   Spit burst- 3 quick shots that aim ahead of where you're running.
##   Splash    - phase 2 only: a ring of shots in every direction.
## After every attack it stands still for `recovery_time` seconds (its punish window:
## no moving, no attacking), then moves around again until the cooldown is up.
## Phase 2 starts below `enrage_health_ratio` health: faster, shorter cooldowns, red tint.
extends EnemyBase
class_name ToiletBrushEnemy

enum Attack { LUNGE, FAN, BURST, RING }

@export_group("Movement")
@export var preferred_distance: float = 75.0
@export var strafe_speed_ratio: float = 0.7      # sideways speed compared to move_speed
@export var strafe_switch_time: Vector2 = Vector2(1.2, 2.6)

@export_group("Attacks")
@export var lunge_range: float = 70.0            # lunges are much more likely inside this
@export var shoot_range: float = 200.0           # won't shoot from further than this
@export var attack_cooldown: float = 1.8         # base; randomised ±35%, counts down after recovery
## Stands still after each attack so the player can hit back (seconds).
@export var recovery_time: float = 0.9
@export var lunge_windup: float = 0.35
@export var lunge_speed: float = 270.0
@export var lunge_duration: float = 0.3
@export var fan_spread_deg: float = 18.0
@export var burst_shots: int = 3
@export var burst_interval: float = 0.18
## 0 = aim at the player, 1 = aim fully at where they'll be when the shot arrives.
@export_range(0.0, 1.0) var burst_lead: float = 0.8
@export var ring_shots: int = 10

@export_group("Ranged spit")
@export var projectile_scene: PackedScene
@export var projectile_damage: float = 0.5
@export var projectile_speed: float = 130.0      # used for aiming ahead
@export var projectile_launch_delay: float = 0.15

@export_group("Phase 2")
@export_range(0.0, 1.0) var enrage_health_ratio: float = 0.5
@export var enraged_speed_mult: float = 1.35
@export var enraged_cooldown_mult: float = 0.7
@export var enraged_recovery_mult: float = 0.65
@export var enraged_tint: Color = Color(1.0, 0.75, 0.75)
@export_group("")


var attack_timer: float = 1.0
var is_lunging: bool = false
var lunge_direction: Vector2 = Vector2.ZERO
var enraged: bool = false
var _last_attack: int = -1
var _strafe_sign: float = 1.0
var _strafe_timer: float = 1.5
var _recover_timer: float = 0.0


func _ready() -> void:
	max_health *= GameState.get_health_multiplier()
	contact_damage = snappedf(contact_damage * GameState.get_damage_multiplier(), 0.5)
	health = max_health
	Discovery.mark_enemy_seen(scene_file_path)
	if phase_shield_at <= 0.0:
		phase_shield_at = enrage_health_ratio  # brief invulnerable moment as phase 2 starts

	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hitbox.area_exited.connect(_on_hitbox_area_exited)
	player = get_tree().get_first_node_in_group("player")

	if is_boss:
		add_to_group("boss")
		EventBus.boss_spawned.emit(max_health)

	sprite.sprite_frames = AnimSheetLoader.build_toilet_brush_frames(
		"res://assets/sprites/enemies/toilet_brush/"
	)
	sprite.play("run_down")
	set_visual_scale(visual_scale)
	_spawn_shadow()
	spawn_timer = spawn_grace_period
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	_update_label()
	# Health bar like every other enemy (EnemyBase._ready isn't called here): shown
	# with the debug view (Tab), replaces the old number label.
	label.visible = false
	var bar: Node2D = HEALTH_BAR.new()
	bar.target = self
	add_child(bar)


func _physics_process(delta: float) -> void:
	if spawn_timer > 0.0:
		spawn_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not enraged and health <= max_health * enrage_health_ratio:
		_enrage()

	if _recover_timer > 0.0:
		_recover_timer -= delta
	elif attack_timer > 0.0:
		attack_timer -= delta   # the cooldown only starts once it has recovered

	if knockback_velocity.length() > 1.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_recovery_speed * delta)
	elif is_stunned():
		velocity = Vector2.ZERO
	elif player:
		var to_player: Vector2 = player.global_position - global_position
		var dist: float = to_player.length()
		var dir: Vector2 = to_player.normalized()

		if action_state == "" and _recover_timer > 0.0:
			velocity = Vector2.ZERO   # recovering: the player's window to hit back
		elif action_state == "":
			_update_facing_direction(dir)
			if attack_timer <= 0.0 and dist <= shoot_range:
				_start_attack(_choose_attack(dist))
			else:
				velocity = _move_velocity(dir, dist, delta)
		else:
			velocity = lunge_direction * lunge_speed if is_lunging else Vector2.ZERO

	_apply_slow_to_velocity(delta)
	move_and_slide()

	if action_state == "":
		if velocity.length() > 0.5:
			_play_run_animation()
		else:
			sprite.stop()


## Approach / back off to preferred_distance, while strafing around the player.
func _move_velocity(dir: Vector2, dist: float, delta: float) -> Vector2:
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(strafe_switch_time.x, strafe_switch_time.y)
		_strafe_sign = -_strafe_sign
	var speed := move_speed * (enraged_speed_mult if enraged else 1.0)
	var radial := 0.0
	if dist > preferred_distance + 15.0:
		radial = 1.0
	elif dist < preferred_distance - 15.0:
		radial = -0.8
	var side := dir.orthogonal() * _strafe_sign * strafe_speed_ratio
	# Bumped into a wall while strafing: go the other way round.
	if get_slide_collision_count() > 0 and get_last_slide_collision().get_collider() is StaticBody2D:
		_strafe_sign = -_strafe_sign
	return (dir * radial + side).normalized() * speed


func _choose_attack(dist: float) -> int:
	var weights := {
		Attack.LUNGE: 5.0 if dist <= lunge_range else 1.5,
		Attack.FAN: 3.0,
		Attack.BURST: 3.0 if dist > lunge_range * 0.6 else 1.0,
		Attack.RING: 2.5 if enraged else 0.0,
	}
	weights.erase(_last_attack)  # never the same attack twice in a row
	var total := 0.0
	for w in weights.values():
		total += w
	var roll := randf() * total
	for key in weights:
		roll -= weights[key]
		if roll <= 0.0:
			return key
	return Attack.FAN


func _start_attack(kind: int) -> void:
	_last_attack = kind
	var cooldown := attack_cooldown * randf_range(0.65, 1.35)
	if enraged:
		cooldown *= enraged_cooldown_mult
	attack_timer = cooldown
	match kind:
		Attack.LUNGE:
			_do_lunge_attack(2 if enraged else 1)
		Attack.FAN:
			_do_spit(_fan_dirs(5 if enraged else 3), 1)
		Attack.BURST:
			_do_burst()
		Attack.RING:
			_do_spit(_ring_dirs(ring_shots), 1)


func _enrage() -> void:
	enraged = true
	sprite.self_modulate = enraged_tint
	attack_timer = minf(attack_timer, 0.4)


# --- Attacks -----------------------------------------------------------------

func _do_lunge_attack(count: int) -> void:
	action_state = "attack"
	velocity = Vector2.ZERO
	for i in count:
		# Wind-up: stand still and flash so the player can read it.
		var anim := "attack_lunge_" + facing_direction
		sprite.play(anim)
		sprite.pause()
		sprite.frame = 0
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0), lunge_windup * 0.5)
		tween.tween_property(sprite, "modulate", Color.WHITE, lunge_windup * 0.5)
		if not await _wait(lunge_windup):
			return
		if player:
			var to_player: Vector2 = player.global_position - global_position
			_update_facing_direction(to_player.normalized())
			lunge_direction = to_player.normalized()
		sprite.play("attack_lunge_" + facing_direction)
		is_lunging = true
		if not await _wait(lunge_duration):
			is_lunging = false
			return
		is_lunging = false
		if i < count - 1 and not await _wait(0.15):
			return
	if sprite.is_playing():
		await sprite.animation_finished
	_end_attack()


func _do_spit(dirs: Array[Vector2], _volleys: int) -> void:
	action_state = "attack"
	velocity = Vector2.ZERO
	sprite.play("attack_spit_" + facing_direction)
	if not await _wait(projectile_launch_delay):
		return
	for d in dirs:
		_spawn_projectile(d)
	if sprite.is_playing():
		await sprite.animation_finished
	_end_attack()


func _do_burst() -> void:
	action_state = "attack"
	velocity = Vector2.ZERO
	for i in burst_shots:
		sprite.play("attack_spit_" + facing_direction)
		if not await _wait(projectile_launch_delay if i == 0 else burst_interval):
			return
		_spawn_projectile(_lead_dir())
	if sprite.is_playing():
		await sprite.animation_finished
	_end_attack()


## Waits `seconds` (pauses with the game). False if the boss died / was interrupted.
func _wait(seconds: float) -> bool:
	await get_tree().create_timer(seconds, false).timeout
	return is_instance_valid(self) and not is_dying and action_state == "attack"


func _end_attack() -> void:
	if is_dying:
		return
	sprite.modulate = Color.WHITE
	if action_state == "attack":
		action_state = ""
		_recover_timer = recovery_time * (enraged_recovery_mult if enraged else 1.0)
		sprite.play("run_" + facing_direction)
		sprite.stop()   # idle pose while recovering


func _aim_dir() -> Vector2:
	if player == null:
		return Vector2.DOWN
	return (get_player_aim_point() - global_position).normalized()


## Aims ahead of a moving player (where they'll be when the shot gets there).
func _lead_dir() -> Vector2:
	if player == null:
		return Vector2.DOWN
	var target := get_player_aim_point()
	var player_vel: Vector2 = player.velocity if "velocity" in player else Vector2.ZERO
	var travel_time := global_position.distance_to(target) / maxf(projectile_speed, 1.0)
	return (target + player_vel * travel_time * burst_lead - global_position).normalized()


func _fan_dirs(count: int) -> Array[Vector2]:
	return ShotPatternModifier.fan(_aim_dir(), count, fan_spread_deg)


func _ring_dirs(count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var offset := randf() * TAU
	for i in count:
		result.append(Vector2.RIGHT.rotated(offset + TAU * i / count))
	return result


## Overrides EnemyBase's version: this sprite set only has down/left/up art,
## so "right" is synthesized by flipping "left" — facing_direction itself
## never stores "right", keeping every animation lookup elsewhere valid.
func _update_facing_direction(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		facing_direction = "left"
		facing_right = dir.x > 0.0
	else:
		facing_direction = "down" if dir.y > 0.0 else "up"
		facing_right = false

	sprite.flip_h = facing_right


func _spawn_projectile(dir: Vector2) -> void:
	if not projectile_scene:
		return
	var proj := projectile_scene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position
	proj.damage = projectile_damage
	if proj.has_method("launch"):
		proj.launch(dir, Vector2.ZERO)


## Contact damage animation (EnemyBase calls this when touching the player).
func _play_attack_animation() -> void:
	if is_dying or action_state != "":
		return
	action_state = "attack"
	sprite.play("attack_lunge_" + facing_direction)
	await sprite.animation_finished
	if is_dying or action_state != "attack":
		return
	action_state = ""
	_play_run_animation()
