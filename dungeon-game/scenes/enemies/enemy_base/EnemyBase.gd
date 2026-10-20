extends CharacterBody2D
class_name EnemyBase

# --- Enemies sprites ---
@export var sprite_sheet_path: String
@export var is_static_visual: bool = false
## > 0: the sheet is ONE row of this many frames, side view facing left (e.g. Rat).
## The enemy only ever faces left/right (mirrored), also while moving up/down.
@export var side_view_frames: int = 0
## Side-view sheets are drawn facing left by default; tick this for art facing right
## (e.g. the snake). With side_view_frames, attack_sheet_path becomes its attack cycle.
@export var side_view_faces_right: bool = false
## Optional extra sheets for side-view enemies moving mostly up/down (same frame layout).
@export_file("*.png") var sheet_up_path: String = ""
@export_file("*.png") var sheet_down_path: String = ""
@export_file("*.png") var attack_sheet_up_path: String = ""
@export_file("*.png") var attack_sheet_down_path: String = ""
## Turn the Hitbox shape with the facing: horizontal side-on, vertical when facing up/down
## (for long bodies like the snake; the shape is authored vertical, e.g. a capsule).
@export var rotate_hitbox_with_facing: bool = false
## Set = sprite_sheet_path is a single-row IDLE sheet and this is a single-row ATTACK
## sheet (square frames, front-facing). See AnimSheetLoader.build_idle_attack_frames().
## Can be the same file as sprite_sheet_path for enemies with one looping cycle (flies).
@export_file("*.png") var attack_sheet_path: String = ""
## Frame rate of the idle/run loop for attack_sheet_path enemies (wings flap fast).
@export var idle_fps: float = 6.0

# --- shadow ---
const SHADOW_SCENE := preload("res://scenes/effects/Shadow.tscn")
@export var shadow_scale_ratio: float = 1.0    # multiplier on top of visual_scale — tune per enemy if its shadow looks off relative to its sprite
@export var shadow_offset: Vector2 = Vector2(0, 6)

var shadow: Shadow = null

# --- Stats ---
@export var max_health: float = 30.0
@export var move_speed: float = 10.0

@export_group("Speed bursts")
## > 0: the enemy alternates between bursts at this speed and its normal move_speed
## (e.g. purple fly: 60 for 3 s, then normal for 5 s, repeating). 0 = off.
@export var burst_speed: float = 0.0
@export var burst_duration: float = 3.0
@export var burst_pause: float = 5.0          # time at normal speed between bursts
@export var burst_anim_speed_scale: float = 2.0  # animation plays faster while bursting
## Pulses between this colour and normal while bursting (on the enemy node itself, so it
## doesn't fight the red hit flash / blue slow tint on the sprite). White = no flashing.
@export var burst_flash_color: Color = Color(1.8, 1.4, 2.0)
@export var burst_flash_period: float = 0.25     # seconds per pulse
@export_group("")

var _base_move_speed: float = 0.0
var _bursting: bool = false
var _burst_timer: float = 0.0
var _burst_tween: Tween = null

# --- Contact damage ---
@export var contact_damage: int = 1
@export var contact_damage_interval: float = 0.6
@export var contact_knockback_strength: float = 100.0

# --- Knockback (received when THIS enemy takes damage) ---
@export var knockback_recovery_speed: float = 800.0
@export var knockback_immune: bool = false
## Knockback is deflected by a random angle between these two values (either side),
## so enemies get knocked off at a diagonal instead of always straight back.
@export var knockback_min_spread_degrees: float = 15.0
@export var knockback_spread_degrees: float = 40.0
## Repeated hits while still in a knockback chain get weaker: each extra hit is
## multiplied by this again (0.5 -> 100%, 50%, 25%...). Stops a stream of shots
## from carrying an enemy across the whole room.
@export_range(0.0, 1.0) var knockback_chain_falloff: float = 0.5
## Time without being hit before the chain resets to full strength.
@export var knockback_chain_reset_time: float = 0.5
## Floor for the chain falloff, so constant fire still nudges enemies a little.
@export_range(0.0, 1.0) var knockback_chain_min: float = 0.25

@export var is_boss: bool = false
## Bosses only (is_boss): incoming knockback is scaled by this, then capped at
## boss_max_knockback (px/s), so high-knockback builds can't shove a boss around.
## Bosses also skip the damage animation (only the white flash) so constant hits
## can't stun-lock them.
@export var boss_knockback_multiplier: float = 0.3
@export var boss_max_knockback: float = 40.0
@export var spawn_grace_period: float = 0.5

@export var movement_behavior: MovementBehavior
## How many of this enemy spawn together per spawn slot (min, max). (1, 1) = alone.
## Swarm enemies (rats) use e.g. (3, 5); the extras appear on free tiles next to the first.
@export var pack_size: Vector2i = Vector2i(1, 1)
## Enemies of the same family ("fly", "rat", ...) tend to spawn together in a room
## (Dungeon.enemy_family_affinity). Empty = no family.
@export var family: StringName = &""
## Pack members are random members of the same family instead of copies of this enemy
## (e.g. a fly cluster with mixed colours).
@export var pack_mixes_family: bool = false
## If set, pack members are THIS scene instead (e.g. a special fly escorted by green
## flies). Takes priority over pack_mixes_family.
@export var pack_member_scene: PackedScene
## Relative chance to be picked for a room spawn slot, vs other enemies in the same
## pool (e.g. common = 3, special = 1).
@export var spawn_weight: float = 1.0
## Spawned where this enemy dies, e.g. FlyRed's explosion. Empty = nothing.
@export var death_scene: PackedScene
@export var attack_behavior: AttackBehavior

var spawn_timer: float = 0.0

## Direction the enemy's body points (last real movement direction). Used for
## vision checks, e.g. LungeAttack only fires at things in front/to the sides.
var heading: Vector2 = Vector2.DOWN

## Set by attacks that move the body themselves (LungeAttack's strike): while active it
## replaces the movement behaviour's velocity. Knockback still wins.
var forced_velocity_active: bool = false
var forced_velocity: Vector2 = Vector2.ZERO

# --- Slow (SlowShotProc) ---
const SLOW_TINT := Color(0.55, 0.75, 1.0)
var _slow_factor: float = 1.0
var _slow_timer: float = 0.0

# --- Confuse (ConfuseShotProc) ---
## While > 0 the enemy stumbles around in random directions and doesn't attack.
var _confuse_timer: float = 0.0
var _confuse_dir: Vector2 = Vector2.RIGHT
var _confuse_turn_timer: float = 0.0
const CONFUSE_TURN_INTERVAL := 0.45

# --- Stun (Emergency Wrench) and rust (Rusty Water): end times in msec ---
var _stun_until_ms: int = 0
var _rust_until_ms: int = 0
var _rust_knockback_mult: float = 1.0
## Pink Eye: marked enemies take this much more damage (PinkEyeStatus sets it).
var damage_taken_mult: float = 1.0
# --- State ---
var health: float
var player: Node2D = null
var is_dying: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var _knockback_chain: int = 0
var _last_knockback_ms: int = -100000

var facing_direction: String = "down"  # down / left / right / up
var facing_right: bool = false 
var action_state: String = ""  # "", "attack", "damage" — prevents run animation from overriding attack/damage

# --- Contact damage ticking ---
var overlapping_hurtboxes: Array[Area2D] = []
var contact_tick_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var label: Label = $Label  # DEBUG ONLY — remove once real enemies ship, no health bars on regular enemies per project plan

@export var visual_scale: float = 1.0

@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox_collision: CollisionShape2D = $Hitbox/CollisionShape2D

func _ready() -> void:
	max_health *= GameState.get_health_multiplier()
	contact_damage = int(round(contact_damage * GameState.get_damage_multiplier()))
	health = max_health

	# Behaviours are shared .tres resources; give each enemy its own copy so state like
	# cooldown timers (RangedAttack) or wander direction (WanderMovement) isn't shared.
	if movement_behavior:
		movement_behavior = movement_behavior.duplicate()
	if attack_behavior:
		attack_behavior = attack_behavior.duplicate()

	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hitbox.area_exited.connect(_on_hitbox_area_exited)
	player = get_tree().get_first_node_in_group("player")

	if is_boss:
		add_to_group("boss")
		EventBus.boss_spawned.emit(max_health)

	if side_view_frames > 0:
		sprite.sprite_frames = AnimSheetLoader.build_side_view_enemy_frames(sprite_sheet_path, side_view_frames, 12.0,
			attack_sheet_path, sheet_up_path, sheet_down_path, attack_sheet_up_path, attack_sheet_down_path)
	elif attack_sheet_path != "":
		sprite.sprite_frames = AnimSheetLoader.build_idle_attack_frames(sprite_sheet_path, attack_sheet_path, idle_fps)
	elif is_static_visual:
		sprite.sprite_frames = AnimSheetLoader.build_static_enemy_frames(sprite_sheet_path)
	else:
		sprite.sprite_frames = AnimSheetLoader.build_enemy_frames(sprite_sheet_path)
	sprite.play("run_down")
	set_visual_scale(visual_scale)
	_spawn_shadow()
	spawn_timer = spawn_grace_period
	_base_move_speed = move_speed
	# Start somewhere in the normal phase so a group doesn't burst in sync.
	_burst_timer = randf_range(1.0, maxf(burst_pause, 1.0))
	_update_label()



func _physics_process(delta: float) -> void:
	if spawn_timer > 0.0:
		spawn_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	if overlapping_hurtboxes.size() > 0:
		contact_tick_timer -= delta
		if contact_tick_timer <= 0.0:
			contact_tick_timer = contact_damage_interval
			_deal_contact_damage()

	# Movement and attack are independent: an enemy can walk AND shoot. Knockback
	# takes over movement while it's active (it used to be overwritten every frame).
	if knockback_velocity.length() > 1.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_recovery_speed * delta)
	elif forced_velocity_active:
		velocity = forced_velocity
	elif is_stunned():
		velocity = Vector2.ZERO
	elif _confuse_timer > 0.0:
		_update_confused(delta)
	elif movement_behavior:
		_update_speed_burst(delta)
		velocity = movement_behavior.get_velocity(self, delta)
	elif player:
		# legacy fallback — old hardcoded chase, so DoktorMugg etc. keep working
		# without needing a MovementBehavior assigned
		var dir := (player.global_position - global_position).normalized()
		velocity = dir * move_speed
		_update_facing_direction(dir)
	else:
		velocity = Vector2.ZERO

	if velocity.length_squared() > 1.0 and knockback_velocity.length() <= 1.0:
		heading = velocity.normalized()

	if attack_behavior and action_state == "" and _confuse_timer <= 0.0 and not is_stunned():
		attack_behavior.try_attack(self, delta)

	_apply_slow_to_velocity(delta)
	move_and_slide()

	if action_state == "":
		_play_run_animation()


func set_visual_scale(value: float) -> void:
	visual_scale = value
	sprite.scale = Vector2.ONE * visual_scale
	body_collision.scale = Vector2.ONE * visual_scale
	hitbox_collision.scale = Vector2.ONE * visual_scale
	if shadow:
		shadow.scale = Vector2.ONE * visual_scale * shadow_scale_ratio


func _update_facing_direction(dir: Vector2) -> void:
	if side_view_frames > 0:
		# Side-view sheets: always the left cycle, mirrored when heading right. Nearly
		# vertical movement keeps the current facing instead of flickering.
		# Up/down art (if any) when moving mostly vertically. Hysteresis so diagonal
		# movement / slither wobble doesn't flicker between side and vertical art.
		var vertical := false
		if sheet_up_path != "" or sheet_down_path != "":
			if facing_direction == "up" or facing_direction == "down":
				vertical = absf(dir.y) >= absf(dir.x) * 0.8
			else:
				vertical = absf(dir.y) > absf(dir.x) * 1.25
		if vertical:
			facing_direction = "down" if dir.y > 0.0 else "up"
			sprite.flip_h = false
		else:
			facing_direction = "left"
			if absf(dir.x) > 0.2:
				facing_right = dir.x > 0.0
			sprite.flip_h = facing_right != side_view_faces_right  # mirror when moving away from the art's facing
		if rotate_hitbox_with_facing:
			hitbox_collision.rotation = 0.0 if vertical else PI / 2.0
		return

	if abs(dir.x) > abs(dir.y):
		if dir.x > 0.0:
			facing_direction = "right"
			facing_right = false
		else:
			facing_direction = "left"
			facing_right = false
	else:
		facing_direction = "down" if dir.y > 0.0 else "up"
		facing_right = false

	# If this enemy's SpriteFrames has no dedicated "right" art, mirror "left" instead.
	if facing_direction == "right" and sprite.sprite_frames and not sprite.sprite_frames.has_animation("run_right"):
		facing_direction = "left"
		facing_right = true

	sprite.flip_h = facing_right


func _play_run_animation() -> void:
	var animation_name := "run_" + facing_direction
	if sprite.animation != animation_name:
		sprite.play(animation_name)


func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, knockback_strength: float = 0.0) -> void:
	if is_dying:
		return

	health -= amount * damage_taken_mult
	_update_label()

	if is_boss:
		EventBus.boss_health_changed.emit(health)

	if health <= 0:
		is_dying = true
		die()
		return

	if Time.get_ticks_msec() < _rust_until_ms:
		knockback_strength *= _rust_knockback_mult

	if not is_boss:
		_play_damage_animation()  # bosses only flash: the hit anim would stun-lock them
	_flash()

	if knockback_strength > 0.0 and not knockback_immune:
		var strength := knockback_strength
		var dir := knockback_dir.normalized()
		if is_boss:
			strength = minf(strength * boss_knockback_multiplier, boss_max_knockback)
		else:
			var now := Time.get_ticks_msec()
			if now - _last_knockback_ms > int(knockback_chain_reset_time * 1000.0):
				_knockback_chain = 0
			_last_knockback_ms = now
			strength *= maxf(pow(knockback_chain_falloff, _knockback_chain), knockback_chain_min)
			_knockback_chain += 1
			if knockback_spread_degrees > 0.0:
				var spread := deg_to_rad(randf_range(knockback_min_spread_degrees, knockback_spread_degrees))
				dir = dir.rotated(spread if randf() < 0.5 else -spread)
		# A weaker follow-up hit never cancels a stronger knockback already in progress.
		if strength >= knockback_velocity.length():
			knockback_velocity = dir * strength


func _play_damage_animation() -> void:
	if is_dying:
		return

	action_state = "damage"
	var animation_name := "damage_" + facing_direction
	sprite.stop()
	sprite.play(animation_name)

	await sprite.animation_finished

	if is_dying:
		return
	if action_state != "damage":  # another state may have taken over while we waited
		return

	action_state = ""
	_play_run_animation()


func _play_attack_animation() -> void:
	if is_dying:
		return
	if action_state == "damage":  # don't interrupt damage
		return
	if action_state == "attack":  # already attacking, don't restart
		return

	action_state = "attack"
	var animation_name := "attack_" + facing_direction
	sprite.play(animation_name)

	await sprite.animation_finished

	if is_dying:
		return
	if action_state != "attack":  # damage animation may have interrupted
		return

	action_state = ""
	_play_run_animation()


func die() -> void:
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	velocity = Vector2.ZERO

	if death_scene:
		var effect := death_scene.instantiate()
		if effect is Node2D:
			(effect as Node2D).position = position
		get_parent().add_child.call_deferred(effect)  # die() runs inside a physics callback (projectile hit)

	var death_animation := "death_" + facing_direction
	if sprite.sprite_frames.has_animation(death_animation):
		sprite.play(death_animation)
		await sprite.animation_finished

	if is_boss:
		EventBus.boss_defeated.emit()

	queue_free()


func _flash() -> void:
	sprite.modulate = Color(1.0, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(sprite):
		sprite.modulate = Color.WHITE


func _update_label() -> void:
	label.text = str(health)


func _on_hitbox_area_entered(area: Area2D) -> void:
	if spawn_timer > 0.0:
		return
	if not overlapping_hurtboxes.has(area):
		overlapping_hurtboxes.append(area)
	contact_tick_timer = contact_damage_interval
	_play_attack_animation()
	_deal_damage_to(area)


func _on_hitbox_area_exited(area: Area2D) -> void:
	overlapping_hurtboxes.erase(area)


func _deal_contact_damage() -> void:
	if spawn_timer > 0.0:
		return
	if overlapping_hurtboxes.is_empty():
		return
	_play_attack_animation()
	for area in overlapping_hurtboxes:
		_deal_damage_to(area)


func _deal_damage_to(area: Area2D) -> void:
	if not is_instance_valid(area):
		return
	var target := area.get_parent()
	if target and target.has_method("take_damage"):
		var knockback_dir: Vector2 = target.global_position - global_position
		target.take_damage(contact_damage, knockback_dir, contact_knockback_strength)


func _spawn_shadow() -> void:
	shadow = SHADOW_SCENE.instantiate()
	var ground_layer := get_tree().get_first_node_in_group("ground_effects")
	var target_parent: Node = ground_layer if ground_layer else get_parent()
	target_parent.add_child(shadow)
	shadow.offset = shadow_offset
	shadow.setup(self, true)  # true — shadow dies with the enemy, unlike the player's persistent version


## Where ranged attacks should aim: the player's hurtbox center (falls back to origin).
func get_player_aim_point() -> Vector2:
	if player == null:
		return global_position
	if player.has_method("get_hurtbox_center"):
		return player.call("get_hurtbox_center")  # player is typed Node2D here
	return player.global_position


## Damage-over-time tick (PoisonStatus): no hit animation, no knockback, so poison
## can't stun-lock. Still kills, and still updates the boss bar.
func take_dot_damage(amount: float, flash_color: Color = Color(0.5, 1.0, 0.4)) -> void:
	if is_dying:
		return
	health -= amount
	_update_label()
	if is_boss:
		EventBus.boss_health_changed.emit(health)
	if health <= 0:
		is_dying = true
		die()
		return
	sprite.modulate = flash_color
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(sprite):
		sprite.modulate = Color.WHITE


## Stuns (no movement, no attacks) for `duration` seconds. Bosses: half as long.
func apply_stun(duration: float) -> void:
	if is_dying:
		return
	var ms := int(duration * (0.5 if is_boss else 1.0) * 1000.0)
	_stun_until_ms = maxi(_stun_until_ms, Time.get_ticks_msec() + ms)


func is_stunned() -> bool:
	return Time.get_ticks_msec() < _stun_until_ms


## Rusty Water: slowed AND takes `knockback_mult` x knockback for `duration` seconds.
func apply_rust(slow_factor: float, knockback_mult: float, duration: float) -> void:
	if is_dying:
		return
	apply_slow(slow_factor, duration)
	_rust_knockback_mult = knockback_mult
	_rust_until_ms = maxi(_rust_until_ms, Time.get_ticks_msec() + int(duration * 1000.0))


## Confuses for `duration` seconds: wanders randomly and can't attack. Bosses are immune.
func apply_confuse(duration: float) -> void:
	if is_dying or is_boss:
		return
	_confuse_timer = maxf(_confuse_timer, duration)
	_confuse_turn_timer = 0.0


func _update_confused(delta: float) -> void:
	_confuse_timer -= delta
	_confuse_turn_timer -= delta
	if _confuse_turn_timer <= 0.0:
		_confuse_turn_timer = CONFUSE_TURN_INTERVAL
		_confuse_dir = Vector2.RIGHT.rotated(randf() * TAU)
	velocity = _confuse_dir * move_speed
	_update_facing_direction(_confuse_dir)


## Slows movement to `factor` (0.5 = half speed) for `duration` seconds. A stronger
## slow replaces a weaker one; re-applying refreshes the timer.
func apply_slow(factor: float, duration: float) -> void:
	if is_dying:
		return
	_slow_factor = minf(factor, _slow_factor) if _slow_timer > 0.0 else factor
	_slow_timer = maxf(_slow_timer, duration)
	sprite.self_modulate = SLOW_TINT  # self_modulate, so the red damage flash (modulate) still works


## Call right before move_and_slide(). Knockback isn't slowed, only own movement.
func _apply_slow_to_velocity(delta: float) -> void:
	if _slow_timer <= 0.0:
		return
	_slow_timer -= delta
	if knockback_velocity.length() <= 1.0:
		velocity *= _slow_factor
	if _slow_timer <= 0.0:
		_slow_factor = 1.0
		sprite.self_modulate = Color.WHITE


## Alternates move_speed between burst_speed (burst_duration) and the normal speed
## (burst_pause). Movement behaviours just read move_speed, so this works with any of them.
func _update_speed_burst(delta: float) -> void:
	if burst_speed <= 0.0:
		return
	_burst_timer -= delta
	if _burst_timer > 0.0:
		return
	_bursting = not _bursting
	_burst_timer = burst_duration if _bursting else burst_pause
	move_speed = burst_speed if _bursting else _base_move_speed
	sprite.speed_scale = burst_anim_speed_scale if _bursting else 1.0
	_set_burst_flash(_bursting)


func _set_burst_flash(on: bool) -> void:
	if _burst_tween:
		_burst_tween.kill()
		_burst_tween = null
	modulate = Color.WHITE
	if not on or burst_flash_color == Color.WHITE:
		return
	_burst_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_burst_tween.tween_property(self, "modulate", burst_flash_color, burst_flash_period / 2.0)
	_burst_tween.tween_property(self, "modulate", Color.WHITE, burst_flash_period / 2.0)
