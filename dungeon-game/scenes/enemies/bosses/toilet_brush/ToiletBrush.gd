extends EnemyBase
class_name ToiletBrushEnemy

# --- Attack ranges ---
@export var lunge_range: float = 40.0      # close enough to bite
@export var shoot_range: float = 220.0     # close enough to spit, too far to bite
@export var attack_cooldown: float = 1.5
@export var lunge_speed: float = 300.0
@export var lunge_duration: float = 0.2  # how long the forward burst lasts


# --- Ranged spit ---
@export var projectile_scene: PackedScene
@export var projectile_damage: float = 1.0
@export var projectile_launch_delay: float = 0.15  # tune to match the actual "launch" frame timing

var attack_timer: float = 0.0
var is_lunging: bool = false
var lunge_direction: Vector2 = Vector2.ZERO

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

	sprite.sprite_frames = AnimSheetLoader.build_toilet_brush_frames(
		"res://assets/sprites/enemies/toilet_brush/"
	)
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

	if attack_timer > 0.0:
		attack_timer -= delta

	if knockback_velocity.length() > 1.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_recovery_speed * delta)
	elif player:
		var to_player: Vector2 = player.global_position - global_position
		var dist: float = to_player.length()
		var dir: Vector2 = to_player.normalized()
		_update_facing_direction(dir)

		if action_state == "":
			if dist <= lunge_range and attack_timer <= 0.0:
				_do_lunge_attack()
			elif dist <= shoot_range and attack_timer <= 0.0:
				_do_shoot_attack(dir)
			elif dist > shoot_range:
				velocity = dir * move_speed
			else:
				velocity = Vector2.ZERO
		else:
			velocity = lunge_direction * lunge_speed if is_lunging else Vector2.ZERO

	move_and_slide()

	if action_state == "":
		if velocity.length() > 0.5:
			_play_run_animation()
		else:
			sprite.stop()


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


func _do_lunge_attack() -> void:
	action_state = "attack"
	attack_timer = attack_cooldown

	var animation_name := "attack_lunge_" + facing_direction
	sprite.play(animation_name)

	lunge_direction = (player.global_position - global_position).normalized() if player else Vector2.ZERO
	is_lunging = true
	await get_tree().create_timer(lunge_duration).timeout
	is_lunging = false

	await sprite.animation_finished

	if is_dying:
		return
	if action_state == "attack":
		action_state = ""


func _do_shoot_attack(dir: Vector2) -> void:
	action_state = "attack"
	attack_timer = attack_cooldown

	var animation_name := "attack_spit_" + facing_direction
	sprite.play(animation_name)

	await get_tree().create_timer(projectile_launch_delay).timeout
	if is_dying or action_state != "attack":
		return
	_spawn_projectile(dir)

	await sprite.animation_finished
	if is_dying:
		return
	if action_state == "attack":
		action_state = ""


func _spawn_projectile(dir: Vector2) -> void:
	if not projectile_scene:
		return
	var proj := projectile_scene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position
	proj.damage = projectile_damage
	if proj.has_method("launch"):
		proj.launch(dir, Vector2.ZERO)


func _play_attack_animation() -> void:
	if is_dying:
		return
	if action_state == "damage":
		return
	if action_state == "attack":
		return

	action_state = "attack"
	var animation_name := "attack_lunge_" + facing_direction
	sprite.play(animation_name)
	await sprite.animation_finished

	if is_dying:
		return
	if action_state != "attack":
		return

	action_state = ""
	_play_run_animation()
