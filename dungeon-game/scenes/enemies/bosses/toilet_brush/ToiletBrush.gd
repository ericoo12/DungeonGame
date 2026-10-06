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
var facing_right: bool = false  # separate from facing_direction, since there's no "right" art to key off of
var is_lunging: bool = false
var lunge_direction: Vector2 = Vector2.ZERO

var _attack_kind: String = ""
var _shot_direction: Vector2 = Vector2.ZERO
var _shot_pending: bool = false

func _setup_animations() -> void:
	sprite.sprite_frames = AnimSheetLoader.build_toilet_brush_frames(
		"res://assets/sprites/enemies/toilet_brush/"
	)


func _update_cooldowns(delta: float) -> void:
	super._update_cooldowns(delta)
	attack_timer = maxf(0.0, attack_timer - delta)


func _update_behavior(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()
	_update_facing_direction(dir)
	if dist <= lunge_range and attack_timer <= 0.0:
		_do_lunge_attack()
	elif dist <= shoot_range and attack_timer <= 0.0:
		_do_shoot_attack(dir)
	elif dist > shoot_range:
		velocity = dir * move_speed


func _update_facing_direction(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		facing_direction = "left"
		facing_right = dir.x > 0.0
	else:
		facing_direction = "down" if dir.y > 0.0 else "up"
		facing_right = false
	sprite.flip_h = facing_right


func _do_lunge_attack() -> void:
	if is_dying or action_state != "" or not is_instance_valid(player):
		return
	if begin_action("attack", "attack_lunge_" + facing_direction, lunge_duration) < 0:
		return
	attack_timer = attack_cooldown
	_attack_kind = "lunge"
	lunge_direction = global_position.direction_to(player.global_position)
	is_lunging = lunge_duration > 0.0
	velocity = lunge_direction * lunge_speed if is_lunging else Vector2.ZERO


func _do_shoot_attack(dir: Vector2) -> void:
	if is_dying or action_state != "" or not projectile_scene:
		return
	if begin_action("attack", "attack_spit_" + facing_direction, projectile_launch_delay) < 0:
		return
	attack_timer = attack_cooldown
	_attack_kind = "spit"
	_shot_direction = dir
	_shot_pending = true


func _update_action(_delta: float) -> void:
	if is_dying or action_state != "attack":
		return
	if _attack_kind == "lunge":
		is_lunging = action_elapsed < lunge_duration
		velocity = lunge_direction * lunge_speed if is_lunging else Vector2.ZERO
	elif _attack_kind == "spit" and _shot_pending and action_elapsed >= projectile_launch_delay:
		_shot_pending = false
		_spawn_projectile(_shot_direction)


func _on_action_ended(_action: String, _cancelled: bool) -> void:
	_attack_kind = ""
	_shot_pending = false
	_shot_direction = Vector2.ZERO
	is_lunging = false
	lunge_direction = Vector2.ZERO


func _spawn_projectile(dir: Vector2) -> void:
	if is_dying or not projectile_scene or not is_inside_tree():
		return
	var proj := projectile_scene.instantiate()
	proj.damage = projectile_damage
	get_parent().add_child(proj)
	proj.global_position = global_position
	if proj.has_method("launch"):
		proj.launch(dir, Vector2.ZERO)


func _play_attack_animation() -> void:
	# Passive contact damage must not start a cosmetic attack that blocks this AI.
	# Only _update_behavior starts the brush's actual lunge/spit actions.
	pass
