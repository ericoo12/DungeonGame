extends CharacterBody2D
class_name EnemyBase

# --- Enemies sprites ---
@export var sprite_sheet_path: String
@export var is_static_visual: bool = false

# --- shadow ---
const SHADOW_SCENE := preload("res://scenes/effects/Shadow.tscn")
@export var shadow_scale_ratio: float = 1.0    # multiplier on top of visual_scale — tune per enemy if its shadow looks off relative to its sprite
@export var shadow_offset: Vector2 = Vector2(0, 6)

var shadow: Shadow = null

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

	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hitbox.area_exited.connect(_on_hitbox_area_exited)
	player = get_tree().get_first_node_in_group("player")

	if is_boss:
		add_to_group("boss")
		EventBus.boss_spawned.emit(max_health)

	if is_static_visual:
		sprite.sprite_frames = AnimSheetLoader.build_static_enemy_frames(sprite_sheet_path)
	else:
		sprite.sprite_frames = AnimSheetLoader.build_enemy_frames(sprite_sheet_path)
	sprite.play("run_down")
	set_visual_scale(visual_scale)
	_spawn_shadow()
	spawn_timer = spawn_grace_period
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

	if knockback_velocity.length() > 1.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_recovery_speed * delta)
	
	if attack_behavior and action_state == "":
		attack_behavior.try_attack(self, delta)
	elif movement_behavior:
		velocity = movement_behavior.get_velocity(self, delta)
	elif player:
		# legacy fallback — old hardcoded chase, so DoktorMugg etc. keep working
		# without needing a MovementBehavior assigned
		var dir := (player.global_position - global_position).normalized()
		velocity = dir * move_speed
		_update_facing_direction(dir)
	else:
		velocity = Vector2.ZERO

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

	health -= amount
	_update_label()

	if is_boss:
		EventBus.boss_health_changed.emit(health)

	if health <= 0:
		is_dying = true
		die()
		return

	_play_damage_animation()
	_flash()

	if knockback_strength > 0.0 and not knockback_immune:
		knockback_velocity = knockback_dir.normalized() * knockback_strength


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
