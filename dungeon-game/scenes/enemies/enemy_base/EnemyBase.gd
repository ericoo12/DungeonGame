extends CharacterBody2D
class_name EnemyBase


# ============================================================
# STATS
# ============================================================

@export var max_health: float = 30.0
@export var move_speed: float = 10.0


# ============================================================
# CONTACT DAMAGE
# ============================================================

@export var contact_damage: int = 1
@export var contact_damage_interval: float = 0.6
@export var contact_knockback_strength: float = 100.0


# ============================================================
# KNOCKBACK
# ============================================================

@export var knockback_recovery_speed: float = 800.0
@export var knockback_immune: bool = false


# ============================================================
# STATE
# ============================================================

var health: float

var player: Node2D = null

var is_dying: bool = false

var knockback_velocity: Vector2 = Vector2.ZERO


# Direction used for animations:
#
# down
# left
# right
# up

var facing_direction: String = "down"


# "", "attack", "damage"
#
# Prevents the run animation from overriding attack/damage.

var action_state: String = ""


# ============================================================
# CONTACT DAMAGE STATE
# ============================================================

var overlapping_hurtboxes: Array[Area2D] = []

var contact_tick_timer: float = 0.0


# ============================================================
# NODES
# ============================================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var label: Label = $Label


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	health = max_health

	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hitbox.area_exited.connect(_on_hitbox_area_exited)

	player = get_tree().get_first_node_in_group("player")


	# ========================================================
	# NEW SPRITESHEET SYSTEM
	# ========================================================
	#
	# One image:
	#
	#         RUN          ATTACK      DAMAGE
	#       0 1 2 3       4 5 6        7 8
	#
	# DOWN
	# LEFT
	# RIGHT
	# UP
	#

	sprite.sprite_frames = AnimSheetLoader.build_enemy_frames(
		"res://assets/sprites/enemies/doktor_mugg/DoktorMugg-Sheet.png"
	)


	sprite.play("run_down")

	_update_label()


# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:

	# --------------------------------------------------------
	# CONTACT DAMAGE TIMER
	# --------------------------------------------------------

	if overlapping_hurtboxes.size() > 0:

		contact_tick_timer -= delta

		if contact_tick_timer <= 0.0:

			contact_tick_timer = contact_damage_interval

			_deal_contact_damage()


	# --------------------------------------------------------
	# KNOCKBACK
	# --------------------------------------------------------

	if knockback_velocity.length() > 1.0:

		velocity = knockback_velocity

		knockback_velocity = knockback_velocity.move_toward(
			Vector2.ZERO,
			knockback_recovery_speed * delta
		)


	# --------------------------------------------------------
	# CHASE PLAYER
	# --------------------------------------------------------

	elif player:

		var dir := (
			player.global_position
			- global_position
		).normalized()


		velocity = dir * move_speed


		_update_facing_direction(dir)


	else:

		velocity = Vector2.ZERO


	move_and_slide()


	# Do NOT override attack/damage animations.

	if action_state == "":

		_play_run_animation()


# ============================================================
# DIRECTION
# ============================================================

func _update_facing_direction(dir: Vector2) -> void:

	# Horizontal movement is stronger.

	if abs(dir.x) > abs(dir.y):

		if dir.x > 0.0:

			facing_direction = "right"

		else:

			facing_direction = "left"


	# Vertical movement is stronger.

	else:

		if dir.y > 0.0:

			facing_direction = "down"

		else:

			facing_direction = "up"


# ============================================================
# RUN ANIMATION
# ============================================================

func _play_run_animation() -> void:

	var animation_name := "run_" + facing_direction


	# Don't restart animation every physics frame.

	if sprite.animation != animation_name:

		sprite.play(animation_name)


# ============================================================
# DAMAGE
# ============================================================

func take_damage(
	amount: float,
	knockback_dir: Vector2 = Vector2.ZERO,
	knockback_strength: float = 0.0
) -> void:

	if is_dying:

		return


	health -= amount

	_update_label()


	if health <= 0:

		is_dying = true

		die()

		return


	# Play directional damage animation.

	_play_damage_animation()


	# Visual flash.

	_flash()


	# Knockback.

	if knockback_strength > 0.0 and not knockback_immune:

		knockback_velocity = (
			knockback_dir.normalized()
			* knockback_strength
		)


# ============================================================
# DAMAGE ANIMATION
# ============================================================

func _play_damage_animation() -> void:

	if is_dying:

		return


	action_state = "damage"


	var animation_name := "damage_" + facing_direction


	sprite.stop()

	sprite.play(animation_name)


	await sprite.animation_finished


	# Maybe another state took over while we waited.

	if is_dying:

		return


	if action_state != "damage":

		return


	action_state = ""

	_play_run_animation()


# ============================================================
# ATTACK
# ============================================================

func _play_attack_animation() -> void:

	if is_dying:

		return


	# Don't interrupt damage.

	if action_state == "damage":

		return


	# Don't restart attack if already attacking.

	if action_state == "attack":

		return


	action_state = "attack"


	var animation_name := "attack_" + facing_direction


	sprite.play(animation_name)


	await sprite.animation_finished


	if is_dying:

		return


	# Damage animation may have interrupted attack.

	if action_state != "attack":

		return


	action_state = ""

	_play_run_animation()


# ============================================================
# DEATH
# ============================================================

func die() -> void:

	set_physics_process(false)

	hitbox.set_deferred("monitoring", false)

	velocity = Vector2.ZERO


	# Your current 4x9 sheet does NOT contain a death animation.
	#
	# If you later add:
	#
	# death_down
	# death_left
	# death_right
	# death_up
	#
	# this will automatically use it.

	var death_animation := "death_" + facing_direction


	if sprite.sprite_frames.has_animation(death_animation):

		sprite.play(death_animation)

		await sprite.animation_finished


	queue_free()


# ============================================================
# FLASH WHEN HIT
# ============================================================

func _flash() -> void:

	sprite.modulate = Color(
		1.0,
		0.3,
		0.3
	)


	await get_tree().create_timer(0.1).timeout


	if is_instance_valid(sprite):

		sprite.modulate = Color.WHITE


# ============================================================
# DEBUG HEALTH LABEL
# ============================================================

func _update_label() -> void:

	label.text = str(health)


# ============================================================
# CONTACT DAMAGE
# ============================================================

func _on_hitbox_area_entered(area: Area2D) -> void:

	if not overlapping_hurtboxes.has(area):

		overlapping_hurtboxes.append(area)


	contact_tick_timer = contact_damage_interval


	# Attack animation whenever enemy hits player.

	_play_attack_animation()


	_deal_damage_to(area)


func _on_hitbox_area_exited(area: Area2D) -> void:

	overlapping_hurtboxes.erase(area)


func _deal_contact_damage() -> void:

	if overlapping_hurtboxes.is_empty():

		return


	# Play attack animation for each contact-damage tick.

	_play_attack_animation()


	for area in overlapping_hurtboxes:

		_deal_damage_to(area)


func _deal_damage_to(area: Area2D) -> void:

	if not is_instance_valid(area):

		return


	var target := area.get_parent()


	if target and target.has_method("take_damage"):

		var knockback_dir: Vector2 = (
			target.global_position
			- global_position
		)


		target.take_damage(
			contact_damage,
			knockback_dir,
			contact_knockback_strength
		)
