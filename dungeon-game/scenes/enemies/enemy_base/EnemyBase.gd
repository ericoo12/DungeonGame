extends CharacterBody2D
class_name EnemyBase

# --- Enemies sprites ---
@export var sprite_sheet_path: String
@export var is_static_visual: bool = false
# --- Stats ---
@export var max_health: float = 30.0
@export var move_speed: float = 10.0

# --- Contact damage ---
@export var contact_damage: int = 1
@export var contact_damage_interval: float = 0.6
@export var contact_knockback_strength: float = 100.0

# --- Knockback (received when THIS enemy takes damage) ---
@export var knockback_recovery_speed: float = 800.0
@export var knockback_immune: bool = false

@export var is_boss: bool = false
@export var spawn_grace_period: float = 0.5

@export var movement_behavior: MovementBehavior
@export var attack_behavior: AttackBehavior

var spawn_timer: float = 0.0
# --- State ---
var health: float
var player: Node2D = null
var is_dying: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO

var facing_direction: String = "down"  # down / left / right / up

# Read-only outside the action lifecycle methods below.
var action_state: String:
	get:
		return _action_state
var _action_state: String = ""
var _action_id: int = 0
var action_elapsed: float = 0.0
var _action_duration: float = 0.0
var _flash_remaining: float = 0.0

signal action_finished(action: String)
signal action_cancelled(action: String)

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
	# Configured resources may be shared; runtime cooldowns/directions must not be.
	if movement_behavior:
		movement_behavior = movement_behavior.duplicate()
	if attack_behavior:
		attack_behavior = attack_behavior.duplicate()
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hitbox.area_exited.connect(_on_hitbox_area_exited)
	player = get_tree().get_first_node_in_group("player")
	_setup_animations()
	_play_run_animation()
	spawn_timer = spawn_grace_period
	set_visual_scale(visual_scale)
	_update_label()
	if is_boss:
		add_to_group("boss")
		EventBus.boss_spawned.emit(max_health)


## Visual customization hook. Subclasses should not replace _ready().
func _setup_animations() -> void:
	if is_static_visual:
		sprite.sprite_frames = AnimSheetLoader.build_static_enemy_frames(sprite_sheet_path)
	else:
		sprite.sprite_frames = AnimSheetLoader.build_enemy_frames(sprite_sheet_path)


## Sole owner of enemy physics and move_and_slide(). AI hooks set velocity only.
func _physics_process(delta: float) -> void:
	velocity = Vector2.ZERO
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(0.0, _flash_remaining - delta)
		if _flash_remaining == 0.0:
			sprite.modulate = Color.WHITE
	if is_dying:
		_advance_action(delta)
		return
	if spawn_timer > 0.0:
		spawn_timer = maxf(0.0, spawn_timer - delta)
	else:
		_update_cooldowns(delta)
		_advance_action(delta)
		if is_dying:
			return
		_tick_contact_damage(delta)
		if knockback_velocity.length() > 1.0:
			velocity = knockback_velocity
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_recovery_speed * delta)
		else:
			knockback_velocity = Vector2.ZERO
			if action_state == "":
				_update_behavior(delta)
			elif action_state == "damage":
				velocity = Vector2.ZERO
	if is_dying:
		return
	move_and_slide()
	if action_state == "":
		if velocity.length() > 0.5:
			_play_run_animation()
		else:
			sprite.stop()


## Runs while alive after spawn protection, including during hurt/attack actions.
func _update_cooldowns(delta: float) -> void:
	if attack_behavior:
		attack_behavior.update_cooldown(delta)


## AI hook: called only when free to decide (not hurt, attacking or knocked back).
## Future boss FSM/BT code must not also self-tick or call move_and_slide().
func _update_behavior(delta: float) -> void:
	if attack_behavior:
		attack_behavior.try_attack(self, delta)
	if action_state != "" or is_dying:
		return
	if movement_behavior:
		velocity = movement_behavior.get_velocity(self, delta)
	elif is_instance_valid(player):
		var dir := global_position.direction_to(player.global_position)
		velocity = dir * move_speed
		_update_facing_direction(dir)


## Starts one bounded action and invalidates the previous action's handle.
## Durations follow the animation's frame timing; min_duration covers late events.
func begin_action(action: String, animation: String, min_duration: float = 0.0) -> int:
	if is_dying or not is_inside_tree():
		return -1
	cancel_action()
	_action_state = action
	action_elapsed = 0.0
	_action_duration = maxf(min_duration, _animation_duration(animation))
	_play_action_animation(animation)
	return _action_id


## Cancels pending effects immediately, including lunge movement and queued shots.
func cancel_action() -> void:
	# Death is terminal; external interruption must not strand a dying enemy.
	if is_dying and _action_state == "death":
		return
	_cancel_current_action()


func _cancel_current_action() -> void:
	var previous := _action_state
	_action_id += 1
	_action_state = ""
	action_elapsed = 0.0
	_action_duration = 0.0
	velocity = Vector2.ZERO
	if previous != "":
		_on_action_ended(previous, true)
		action_cancelled.emit(previous)


func is_action_current(handle: int) -> bool:
	return handle >= 0 and handle == _action_id and _action_state != "" and is_inside_tree()


func finish_action(handle: int) -> void:
	if not is_action_current(handle):
		return
	var previous := _action_state
	_action_id += 1
	_action_state = ""
	action_elapsed = 0.0
	_action_duration = 0.0
	velocity = Vector2.ZERO
	_on_action_ended(previous, false)
	action_finished.emit(previous)
	if previous == "death":
		if is_boss:
			EventBus.boss_defeated.emit()
		queue_free()


func _advance_action(delta: float) -> void:
	if action_state == "":
		return
	var handle := _action_id
	action_elapsed += delta
	_update_action(delta)
	if is_action_current(handle) and action_elapsed >= _action_duration:
		finish_action(handle)


## Action execution hook: evaluate pending effects using action_elapsed.
func _update_action(_delta: float) -> void:
	pass


## Cleanup hook, called on completion AND cancellation. Never launch effects here.
func _on_action_ended(_action: String, _cancelled: bool) -> void:
	pass


func _animation_duration(animation: String) -> float:
	var frames := sprite.sprite_frames
	if not frames or not frames.has_animation(animation):
		return 0.1
	var duration := 0.0
	for i in frames.get_frame_count(animation):
		duration += frames.get_frame_duration(animation, i)
	return maxf(0.01, duration / maxf(0.01, frames.get_animation_speed(animation) * absf(sprite.speed_scale)))


func _play_action_animation(animation: String) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(animation):
		sprite.stop()
		sprite.play(animation)


func set_visual_scale(value: float) -> void:
	visual_scale = value
	sprite.scale = Vector2.ONE * visual_scale
	body_collision.scale = Vector2.ONE * visual_scale
	hitbox_collision.scale = Vector2.ONE * visual_scale


func _update_facing_direction(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		facing_direction = "right" if dir.x > 0.0 else "left"
	else:
		facing_direction = "down" if dir.y > 0.0 else "up"


func _play_run_animation() -> void:
	var animation_name := "run_" + facing_direction
	if sprite.sprite_frames.has_animation(animation_name):
		if sprite.animation != animation_name or not sprite.is_playing():
			sprite.play(animation_name)


func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, knockback_strength: float = 0.0) -> void:
	if is_dying:
		return
	health -= amount
	_update_label()
	if is_boss:
		EventBus.boss_health_changed.emit(health)
	if health <= 0:
		die()
		return
	_play_damage_animation()
	_flash()
	if knockback_strength > 0.0 and not knockback_immune:
		knockback_velocity = knockback_dir.normalized() * knockback_strength


func _play_damage_animation() -> void:
	begin_action("damage", "damage_" + facing_direction)


func _play_attack_animation() -> void:
	if action_state == "" and not is_dying:
		begin_action("attack", "attack_" + facing_direction)


func die() -> void:
	if is_dying:
		return
	# Keep only the bounded death action ticking; no AI, contacts or movement.
	is_dying = true
	_cancel_current_action()
	knockback_velocity = Vector2.ZERO
	overlapping_hurtboxes.clear()
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	body_collision.set_deferred("disabled", true)
	var animation := "death_" + facing_direction
	_action_state = "death"
	_action_duration = _animation_duration(animation)
	_play_action_animation(animation)
	if not sprite.sprite_frames.has_animation(animation):
		finish_action(_action_id)


func _exit_tree() -> void:
	_cancel_current_action()


func _flash() -> void:
	sprite.modulate = Color(1.0, 0.3, 0.3)
	_flash_remaining = 0.1


func _update_label() -> void:
	label.text = str(health)


func _tick_contact_damage(delta: float) -> void:
	if overlapping_hurtboxes.is_empty():
		return
	contact_tick_timer -= delta
	if contact_tick_timer <= 0.0:
		contact_tick_timer = contact_damage_interval
		_deal_contact_damage()


func _on_hitbox_area_entered(area: Area2D) -> void:
	if is_dying or not is_instance_valid(area):
		return
	var target := area.get_parent()
	if not target or not target.has_method("take_damage"):
		return
	if not overlapping_hurtboxes.has(area):
		overlapping_hurtboxes.append(area)
	# Remember overlaps during grace; begin damage once grace ends.
	if spawn_timer > 0.0:
		return
	contact_tick_timer = contact_damage_interval
	_play_attack_animation()
	_deal_damage_to(area)


func _on_hitbox_area_exited(area: Area2D) -> void:
	overlapping_hurtboxes.erase(area)


func _deal_contact_damage() -> void:
	if is_dying or spawn_timer > 0.0:
		return
	_play_attack_animation()
	for area in overlapping_hurtboxes:
		_deal_damage_to(area)


func _deal_damage_to(area: Area2D) -> void:
	if is_dying or not is_instance_valid(area):
		return
	var target := area.get_parent()
	if target and target.has_method("take_damage"):
		var knockback_dir: Vector2 = target.global_position - global_position
		target.take_damage(contact_damage, knockback_dir, contact_knockback_strength)
