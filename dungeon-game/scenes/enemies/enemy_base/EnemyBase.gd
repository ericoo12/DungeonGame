extends CharacterBody2D
class_name EnemyBase

@export var max_health: float = 30.0
@export var move_speed: float = 10.0
@export var contact_damage: int = 1
@export var contact_damage_interval: float = 0.6
@export var knockback_recovery_speed: float = 800.0
@export var contact_knockback_strength: float = 100.0
@export var knockback_immune: bool = false

var overlapping_hurtboxes: Array[Area2D] = []
var contact_tick_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var health: float
var player: Node2D = null
var facing_flip: bool = false
var is_dying: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var label: Label = $Label


func _ready() -> void:
	health = max_health
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hitbox.area_exited.connect(_on_hitbox_area_exited)
	player = get_tree().get_first_node_in_group("player")
	sprite.sprite_frames = AnimSheetLoader.build_enemy_frames({
		"run":   {"path": "res://assets/sprites/enemies/rouge_enemy/Run-Sheet.png",   "count": 6},
		"idle":  {"path": "res://assets/sprites/enemies/rouge_enemy/Idle-Sheet.png",  "count": 4},
		"death": {"path": "res://assets/sprites/enemies/rouge_enemy/Death-Sheet.png", "count": 6},
	})
	sprite.play("run")
	_update_label()


func _physics_process(delta: float) -> void:
	if overlapping_hurtboxes.size() > 0:
		contact_tick_timer -= delta
		if contact_tick_timer <= 0.0:
			contact_tick_timer = contact_damage_interval
			_deal_contact_damage()
			
	if knockback_velocity.length() > 1.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_recovery_speed * delta)
	elif player:
		var dir := (player.global_position - global_position).normalized()
		velocity = dir * move_speed
		if dir.x != 0.0:
			facing_flip = dir.x < 0
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	sprite.flip_h = facing_flip

	
func _update_label() -> void:
	label.text = str(health)


func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, knockback_strength: float = 0.0) -> void:
	if is_dying:
		return
	health -= amount
	_update_label()
	if health <= 0:
		is_dying = true
		die()
	else:
		_flash()
		if knockback_strength > 0.0 and not knockback_immune:
			knockback_velocity = knockback_dir.normalized() * knockback_strength


func _flash() -> void:
	sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(sprite):
		sprite.modulate = Color(1, 1, 1)


func die() -> void:
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	velocity = Vector2.ZERO
	
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
		
	queue_free()


func _on_hitbox_area_entered(area: Area2D) -> void:
	overlapping_hurtboxes.append(area)
	contact_tick_timer = contact_damage_interval
	_deal_damage_to(area)

func _on_hitbox_area_exited(area: Area2D) -> void:
	overlapping_hurtboxes.erase(area)

func _deal_contact_damage() -> void:
	for area in overlapping_hurtboxes:
		_deal_damage_to(area)

func _deal_damage_to(area: Area2D) -> void:
	var target := area.get_parent()
	if target and target.has_method("take_damage"):
		var knockback_dir : Vector2 = target.global_position - global_position
		target.take_damage(contact_damage, knockback_dir, contact_knockback_strength)
