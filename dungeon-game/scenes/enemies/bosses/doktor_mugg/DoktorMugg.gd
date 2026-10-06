extends EnemyBase
class_name DoktorMugg

@export_category("Tactics")
@export_range(0.05, 1.0) var decision_interval: float = 0.2
@export var preferred_distance: float = 155.0
@export var close_distance: float = 85.0
@export var attack_range: float = 280.0
@export var memory_duration: float = 3.0
@export var movement_commitment: float = 0.65
@export var movement_timeout: float = 1.6
@export var reposition_cooldown: float = 0.8
@export var navigation_radius: float = 20.0
## 0 changes the random sequence each run; a fixed number reproduces choices.
@export var random_seed: int = 0
@export var debug_ai: bool = false

@export_category("Health Tactics")
@export var health_tactics_enabled: bool = true
@export_range(0.1, 1.0, 0.05) var player_low_health_threshold: float = 0.5
@export_range(0.1, 1.0, 0.05) var boss_low_health_threshold: float = 0.45
@export_range(1.0, 5.0, 0.1) var low_player_attack_weight_boost: float = 3.0
@export_range(0.3, 1.0, 0.05) var low_player_cooldown_scale: float = 0.5
@export var low_player_close_in_distance: float = 45.0
@export var low_boss_extra_distance: float = 75.0
@export_range(0.0, 0.5, 0.05) var low_boss_dodge_bonus: float = 0.2
@export_range(0.3, 1.0, 0.05) var low_boss_defense_cooldown_scale: float = 0.55
@export_range(1.0, 5.0, 0.1) var low_boss_movement_weight_boost: float = 3.0
@export_range(1.0, 3.0, 0.1) var low_boss_cover_hold_boost: float = 1.5

@export_category("Kiting")
@export var kiting_enabled: bool = true
## Disable ordinary hit stagger for sustained kiting; explicit stun still interrupts.
@export var kite_hit_stagger: bool = false
## Movement during windup; the final plant window and release remain stationary.
@export_range(0.0, 1.0, 0.05) var kite_windup_speed: float = 0.4
@export_range(0.0, 1.5, 0.05) var kite_recovery_speed: float = 1.0
@export_range(0.0, 0.3, 0.01) var kite_plant_window: float = 0.1
@export var kite_spacing_tolerance: float = 30.0
@export var kite_probe_distance: float = 45.0
@export var kite_direction_interval: float = 1.7
@export_range(0.0, 1.0, 0.05) var kite_reverse_chance: float = 0.4
@export var kite_strafe_weight: float = 1.4
@export var kite_spacing_weight: float = 3.0
## Predict only from consecutive visible observations, never hidden movement.
@export_range(0.0, 1.0, 0.05) var aim_lead_strength: float = 0.0
@export var aim_lead_max_distance: float = 55.0

@export_category("Basic Shot")
@export var projectile_scene: PackedScene
@export var projectile_damage: float = 1.0
@export var projectile_speed: float = 160.0
@export_range(0.1, 3.0) var windup_duration: float = 0.55
@export_range(0.01, 1.0) var fire_duration: float = 0.08
@export_range(0.1, 3.0) var recovery_duration: float = 0.65
@export var attack_cooldown: float = 1.8

@export_category("Running Shot")
## Quick cyan shot fired while kiting at full speed, including release.
@export_range(0.0, 10.0, 0.1) var running_shot_weight: float = 3.0
@export_range(0.05, 0.5, 0.01) var running_shot_windup: float = 0.12
@export_range(0.05, 0.5, 0.01) var running_shot_recovery: float = 0.16
@export var running_shot_speed: float = 205.0
@export var running_shot_cooldown: float = 0.65

@export_category("Cluster Shot")
@export_range(0.0, 10.0, 0.1) var cluster_weight: float = 2.0
@export_range(3, 9, 1) var cluster_count: int = 5
@export_range(10.0, 90.0, 1.0) var cluster_cone_degrees: float = 38.0
## Jitter within each cone sector; keeps the spread irregular without clumping.
@export_range(0.0, 1.0, 0.05) var cluster_scatter: float = 0.8
@export var cluster_speed: float = 145.0
@export_range(0.0, 0.4, 0.01) var cluster_speed_variation: float = 0.12
@export var cluster_damage: float = 1.0
@export var cluster_lifetime: float = 2.2
@export var cluster_windup: float = 0.7

@export_category("Homing Shot")
@export_range(0.0, 10.0, 0.1) var homing_near_weight: float = 0.25
@export_range(0.0, 10.0, 0.1) var homing_far_weight: float = 3.0
@export var homing_near_distance: float = 80.0
@export var homing_far_distance: float = 280.0
@export var homing_speed: float = 145.0
@export_range(10.0, 180.0, 5.0) var homing_turn_rate: float = 85.0
@export var homing_tracking_duration: float = 1.6
@export var homing_tracking_delay: float = 0.2
@export var homing_lifetime: float = 3.2
@export var homing_damage: float = 1.0
@export var homing_windup: float = 0.85
@export var homing_cooldown: float = 6.0
@export var homing_color := Color(0.75, 0.25, 1.0)

@export_category("Dodge — Reaction")
## Roll once per incoming projectile, when not committed and cooldown is ready.
@export var dodge_enabled: bool = true
@export_range(0.0, 1.0, 0.05) var dodge_chance: float = 0.65
@export_range(0.1, 2.0, 0.05) var dodge_lookahead: float = 0.65
@export_range(20.0, 500.0, 5.0) var dodge_detection_range: float = 180.0
## Predicted collision corridor, including the boss and projectile footprint.
@export_range(10.0, 80.0, 1.0) var dodge_threat_radius: float = 30.0
@export_range(0.0, 10.0, 0.1) var dodge_cooldown: float = 2.5

@export_category("Dodge — Movement")
@export_range(50.0, 600.0, 10.0) var dodge_speed: float = 320.0
@export_range(0.05, 0.8, 0.01) var dodge_duration: float = 0.22
@export_range(0.05, 1.0, 0.01) var dodge_recovery: float = 0.25
## Relative weights; zero disables a direction. Blocked routes are excluded.
@export_range(0.0, 10.0, 0.1) var dodge_left_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var dodge_right_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var dodge_away_weight: float = 0.5
@export_range(0.0, 10.0, 0.1) var dodge_diagonal_weight: float = 0.75

@export_category("Position Preferences")
@export_range(0.0, 20.0, 0.1) var clear_position_weight: float = 5.0
@export_range(0.0, 20.0, 0.1) var blocked_position_weight: float = 0.5
## Larger values reduce the preference for nearby destinations.
@export_range(10.0, 600.0, 10.0) var position_distance_scale: float = 150.0

@export_category("Tactic Probabilities")
## Relative weights when a clear shot is available: defaults are 75% / 25%.
@export_range(0.0, 10.0, 0.1) var basic_shot_weight: float = 3.0
@export_range(0.0, 10.0, 0.1) var tactical_move_weight: float = 1.0
## Avoid rolling the same tactical choice every decision tick.
@export_range(0.1, 3.0, 0.1) var tactic_choice_interval: float = 0.8
## Random +/- fraction of shot/dodge cooldown; 0 gives fixed timings.
@export_range(0.0, 0.75, 0.05) var cooldown_variation: float = 0.2

@export_category("Take Cover")
@export var cover_enabled: bool = true
@export_range(40.0, 350.0, 10.0) var cover_search_distance: float = 180.0
@export_range(0.1, 2.0, 0.1) var cover_hold_duration: float = 0.6
@export_range(0.5, 10.0, 0.1) var cover_cooldown: float = 3.5

@export_category("Area Attack")
@export var area_enabled: bool = true
@export_range(20.0, 120.0, 5.0) var area_radius: float = 60.0
@export_range(0.4, 2.5, 0.05) var area_warning: float = 0.9
@export_range(0.2, 4.0, 0.1) var area_lifetime: float = 1.4
@export var area_damage: float = 1.0
@export_range(0.1, 2.0, 0.05) var area_recovery: float = 0.5
@export_range(1.0, 15.0, 0.1) var area_cooldown: float = 5.0
@export var area_range: float = 300.0
@export var area_defensive_distance: float = 95.0
@export var area_cover_delay: float = 0.6
@export_range(0.0, 1.0, 0.05) var area_anti_cover_chance: float = 0.8
@export_range(0.0, 1.0, 0.05) var area_defensive_chance: float = 0.5
## A failed area roll cannot repeat until this many seconds have passed.
@export_range(0.2, 3.0, 0.1) var area_choice_interval: float = 1.2

@onready var state_machine: MuggStateMachine = $StateMachine
@onready var behavior_tree: MuggBehaviorTree = $BehaviorTree
@onready var navigator: ArenaNavigator = $Navigation
var blackboard := MuggBlackboard.new()
var arena: RoomController
var _rng := RandomNumberGenerator.new()
var _decision_timer: float = 0.0
var _shot_cooldown: float = 0.0
var _reposition_timer: float = 0.0
var _shot_pending: bool = false
var _locked_aim: Vector2 = Vector2.DOWN
var _locked_target: Vector2
var _last_position: Vector2
var _stuck_time: float = 0.0
var _movement_retry: float = 0.0
var _dodge_timer: float = 0.0
var _offense_timer: float = 0.0
var _dodge_direction := Vector2.ZERO
var _dodge_moved_time: float = 0.0
# IDs are retained only while their projectile exists: one probability roll per threat.
var _considered_projectiles: Dictionary = {}
var _cover_timer: float = 0.0
var _recent_damage: float = 0.0
var _area_timer: float = 0.0
var _area_choice_timer: float = 0.0
var _blocked_duration: float = 0.0
var _pending_area: MuggAreaAttack
var _active_windup: float = 0.55
var _active_recovery: float = 0.65
var _homing_timer: float = 0.0
var _kite_side: float = 1.0
var _kite_side_timer: float = 0.0
var _kite_steer_timer: float = 0.0
var _kite_direction := Vector2.ZERO
var _observed_player_velocity := Vector2.ZERO
var _observed_player_health_ratio: float = 1.0




func _setup_animations() -> void:
	super._setup_animations()
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	behavior_tree.configure(self)
	state_machine.state_changed.connect(func(_previous, _current): queue_redraw())
	label.visible = debug_ai

func set_arena(room: RoomController) -> void:
	arena = room
	blackboard.forget()
	_observed_player_health_ratio = 1.0
	navigator.configure(self, room, navigation_radius)
	_last_position = global_position
	_decision_timer = 0.0

func _update_cooldowns(delta: float) -> void:
	super._update_cooldowns(delta)
	state_machine.advance(delta)
	_kite_side_timer -= delta
	_kite_steer_timer -= delta
	_homing_timer = maxf(0.0, _homing_timer - delta)
	_cover_timer = maxf(0, _cover_timer - delta)
	_recent_damage = maxf(0, _recent_damage - delta)
	_area_timer = maxf(0, _area_timer - delta)
	_area_choice_timer = maxf(0, _area_choice_timer - delta)
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_offense_timer = maxf(0.0, _offense_timer - delta)
	_shot_cooldown = maxf(0.0, _shot_cooldown - delta)
	_reposition_timer = maxf(0.0, _reposition_timer - delta)
	_movement_retry = maxf(0.0, _movement_retry - delta)
	_decision_timer -= delta
	if not is_instance_valid(arena):
		blackboard.forget()
		return
	navigator.update(delta)
	_update_perception(delta)
	_blocked_duration = _blocked_duration + delta if blackboard.has_last_seen and not blackboard.shot_clear else 0.0
	queue_redraw()
	if debug_ai:
		label.text = "%s | %.0f HP" % [state_machine.state_name(), health]

func _update_perception(delta: float) -> void:
	var previously_visible := blackboard.player_visible
	var previous_observation := blackboard.last_seen_position
	blackboard.player_visible = false
	blackboard.shot_clear = false
	if not is_instance_valid(player) or (player is Player and player.is_dying):
		blackboard.forget()
		return
	# Current position is used ONLY to determine visibility. Hidden-player
	# tactics and distances below use the stored observation, never live tracking.
	if arena.has_clear_sight(global_position, player.global_position):
		_observed_player_velocity = (player.global_position - previous_observation) / maxf(delta, 0.001) if previously_visible else Vector2.ZERO
		_observed_player_velocity = _observed_player_velocity.limit_length(250.0)
		if player is Player:
			_observed_player_health_ratio = clampf(float(player.current_hearts) / maxf(player.max_hearts, 1), 0, 1)
		blackboard.player_visible = true
		blackboard.has_last_seen = true
		blackboard.last_seen_position = player.global_position
		blackboard.time_since_seen = 0.0
		blackboard.shot_clear = has_clear_shot(global_position, player.global_position)
	else:
		_observed_player_velocity = Vector2.ZERO
		blackboard.time_since_seen += delta
		if blackboard.time_since_seen > memory_duration:
			blackboard.has_last_seen = false
	blackboard.distance = global_position.distance_to(blackboard.last_seen_position) if blackboard.has_last_seen else INF

func has_clear_shot(from: Vector2, to: Vector2) -> bool:
	# Swept projectile footprint, separate from movement and sight blockers.
	var shape := CircleShape2D.new()
	shape.radius = 9.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, from)
	query.collision_mask = 1 | (1 << 8)
	var space := get_world_2d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	query.motion = to - from
	return space.cast_motion(query)[0] >= 0.999

func _update_behavior(delta: float) -> void:
	if not is_instance_valid(arena) or not navigator.ready_for_paths:
		return
	if _try_hold_cover():
		return
	if _decision_timer <= 0.0:
		_decision_timer = decision_interval
		behavior_tree.tick()
	if state_machine.state == MuggStateMachine.State.KITE:
		velocity = _kite_velocity(delta)
		if velocity == Vector2.ZERO:
			var escape := _choose_position(false)
			if not escape.is_empty():
				navigator.set_path(escape)
				state_machine.transition(MuggStateMachine.State.REPOSITION)
		if velocity.length_squared() > 0.01:
			_update_facing_direction(velocity.normalized())
		return
	if state_machine.state in [MuggStateMachine.State.PRESSURE, MuggStateMachine.State.REPOSITION, MuggStateMachine.State.TAKE_COVER]:
		velocity = navigator.desired_velocity(global_position, move_speed, delta)
		if velocity.length_squared() > 0.01:
			_update_facing_direction(velocity.normalized())
			_stuck_time = _stuck_time + delta if global_position.distance_to(_last_position) < 0.2 else 0.0
		else:
			_stuck_time = 0.0
		_last_position = global_position
		if _try_hold_cover():
			return
		if navigator.path.is_empty() or state_machine.elapsed >= (cover_search_distance / maxf(move_speed, 1) + 0.5 if state_machine.state == MuggStateMachine.State.TAKE_COVER else movement_timeout) or _stuck_time > 0.4:
			navigator.stop()
			state_machine.transition(MuggStateMachine.State.IDLE)
			_decision_timer = 0.0
			_stuck_time = 0.0

func movement_is_committed() -> bool:
	if state_machine.state == MuggStateMachine.State.TAKE_COVER and not navigator.path.is_empty():
		return true
	return state_machine.state in [MuggStateMachine.State.PRESSURE, MuggStateMachine.State.REPOSITION, MuggStateMachine.State.TAKE_COVER] and state_machine.elapsed < movement_commitment and not navigator.path.is_empty()

func bad_position() -> bool:
	var safe_bounds := arena.get_arena_bounds().grow(-navigation_radius - 20.0)
	return not safe_bounds.has_point(global_position) or blackboard.distance > effective_preferred_distance() + 70.0

func can_basic_shot() -> bool:
	return projectile_scene != null and _shot_cooldown <= 0.0 and blackboard.player_visible and blackboard.shot_clear and blackboard.distance <= attack_range

func ai_dead() -> DecisionNode.Status:
	state_machine.transition(MuggStateMachine.State.DEAD, true)
	return DecisionNode.Status.SUCCESS

func ai_stunned() -> DecisionNode.Status:
	state_machine.transition(MuggStateMachine.State.STUNNED, true)
	return DecisionNode.Status.RUNNING

func ai_idle() -> DecisionNode.Status:
	navigator.stop()
	state_machine.transition(MuggStateMachine.State.IDLE)
	blackboard.last_decision = "Wait for sight"
	return DecisionNode.Status.SUCCESS

func ai_reposition(reason: String) -> DecisionNode.Status:
	if kiting_enabled and blackboard.player_visible and reason == "Create distance":
		# Fire while retreating when ready; otherwise keep opening space.
		if can_basic_shot() and _offense_timer <= 0:
			return ai_choose_offense()
		return _start_kiting()
	if _reposition_timer > 0.0 or _movement_retry > 0.0:
		return DecisionNode.Status.FAILURE
	var route := _choose_position(reason == "Create distance")
	if route.is_empty():
		_movement_retry = 0.3
		return DecisionNode.Status.FAILURE
	if not state_machine.transition(MuggStateMachine.State.REPOSITION):
		return DecisionNode.Status.FAILURE
	navigator.set_path(route)
	_reposition_timer = movement_timeout + reposition_cooldown
	blackboard.last_decision = reason
	return DecisionNode.Status.RUNNING

func ai_pressure() -> DecisionNode.Status:
	if kiting_enabled and blackboard.player_visible and blackboard.shot_clear:
		return _start_kiting()
	if movement_is_committed():
		return DecisionNode.Status.RUNNING
	if not blackboard.has_last_seen or _movement_retry > 0.0:
		return DecisionNode.Status.FAILURE
	# Reuse an active route until its time limit instead of rerolling each tick.
	if state_machine.state in [MuggStateMachine.State.PRESSURE, MuggStateMachine.State.REPOSITION, MuggStateMachine.State.TAKE_COVER] and not navigator.path.is_empty():
		return DecisionNode.Status.RUNNING
	var route := _choose_position(false)
	if route.is_empty():
		_movement_retry = 0.3
		return DecisionNode.Status.FAILURE
	state_machine.transition(MuggStateMachine.State.PRESSURE)
	navigator.set_path(route)
	blackboard.last_decision = "Pressure" if blackboard.player_visible else "Investigate last sighting"
	return DecisionNode.Status.RUNNING

func _choose_position(retreat: bool) -> PackedVector2Array:
	var routes: Array[PackedVector2Array] = []
	var weights: Array[float] = []
	var total := 0.0
	var target := blackboard.last_seen_position
	var angle_offset := _rng.randf_range(0.0, TAU)
	for i in 16:
		var angle := angle_offset + TAU * float(i) / 16.0
		var distance := effective_preferred_distance() * (0.8 if i % 2 == 0 else 1.15)
		var candidate := arena.clamp_to_arena(target + Vector2.from_angle(angle) * distance, navigation_radius + 8.0)
		if candidate.distance_to(global_position) < 24.0:
			continue
		if retreat and candidate.distance_to(target) < blackboard.distance + 20.0:
			continue
		var route := navigator.path_to(global_position, candidate)
		if route.is_empty():
			continue
		var clear_angle := arena.has_clear_sight(candidate, target) and has_clear_shot(candidate, target)
		var weight := clear_position_weight if clear_angle else blocked_position_weight
		if weight <= 0.0:
			continue
		weight /= 1.0 + global_position.distance_to(candidate) / maxf(1.0, position_distance_scale)
		routes.append(route)
		weights.append(weight)
		total += weight
	if routes.is_empty():
		return PackedVector2Array()
	var pick := _rng.randf() * total
	for i in routes.size():
		pick -= weights[i]
		if pick <= 0.0:
			return routes[i]
	return routes[-1]

func ai_basic_shot(kind: String = "basic_shot") -> DecisionNode.Status:
	if not can_basic_shot() or state_machine.is_committed() or is_dying:
		return DecisionNode.Status.FAILURE
	navigator.stop()
	_locked_target = blackboard.last_seen_position
	if kind != "homing_shot" and aim_lead_strength > 0:
		var flight_time := blackboard.distance / maxf(1, cluster_speed if kind == "cluster_shot" else (running_shot_speed if kind == "running_shot" else projectile_speed))
		_locked_target += (_observed_player_velocity * flight_time * aim_lead_strength).limit_length(aim_lead_max_distance)
	_locked_aim = global_position.direction_to(_locked_target)
	_update_facing_direction(_locked_aim)
	_active_windup = cluster_windup if kind == "cluster_shot" else (homing_windup if kind == "homing_shot" else windup_duration)
	_active_recovery = recovery_duration
	if kind == "running_shot":
		_active_windup = running_shot_windup
		_active_recovery = running_shot_recovery
	_active_windup = maxf(0.05, _active_windup)
	var duration := _active_windup + fire_duration + _active_recovery
	# Gameplay timing must not be extended by the placeholder animation length.
	if begin_action(kind, "", duration) < 0:
		return DecisionNode.Status.FAILURE
	sprite.play("attack_" + facing_direction)
	sprite.pause()
	state_machine.transition(MuggStateMachine.State.WINDUP, true)
	_shot_pending = true
	_shot_cooldown = maxf(_varied_cooldown((running_shot_cooldown if kind == "running_shot" else attack_cooldown) * effective_attack_cooldown_scale()), duration)
	blackboard.last_attack = "Cluster Shot" if kind == "cluster_shot" else ("Homing Shot" if kind == "homing_shot" else "Basic Shot")
	if kind == "running_shot":
		blackboard.last_attack = "Running Shot"
	blackboard.last_decision = blackboard.last_attack
	if kind == "homing_shot":
		_homing_timer = maxf(homing_cooldown, duration)
	queue_redraw()
	return DecisionNode.Status.RUNNING

func _update_action(_delta: float) -> void:
	if action_state == "cover_hold":
		if blackboard.player_visible and has_clear_shot(blackboard.last_seen_position, global_position):
			cancel_action()
		return
	if action_state == "area_attack":
		if is_instance_valid(_pending_area):
			_pending_area.warning_progress = clampf(action_elapsed / area_warning, 0, 1)
			_pending_area.queue_redraw()
			if action_elapsed >= area_warning:
				_pending_area.arm()
				_pending_area = null
				state_machine.transition(MuggStateMachine.State.AREA_RECOVERY, true)
		return
	if action_state == "dodge" and not is_dying:
		_update_dodge(_delta)
		return
	if is_dying or action_state not in ["basic_shot", "cluster_shot", "homing_shot", "running_shot"]:
		return
	if kiting_enabled:
		if action_state == "running_shot":
			velocity = _kite_velocity(_delta)
		elif action_elapsed < _active_windup - kite_plant_window:
			velocity = _kite_velocity(_delta) * kite_windup_speed
		elif action_elapsed >= _active_windup + fire_duration:
			velocity = _kite_velocity(_delta) * kite_recovery_speed
	if action_elapsed >= _active_windup and _shot_pending:
		_shot_pending = false
		state_machine.transition(MuggStateMachine.State.FIRE, true)
		sprite.play("attack_" + facing_direction)
		# Commit to the original direction, never re-aim at a hidden/moving player.
		if has_clear_shot(global_position, global_position + _locked_aim * global_position.distance_to(_locked_target)):
			_fire_selected_shot()
	if action_elapsed >= _active_windup + fire_duration:
		state_machine.transition(MuggStateMachine.State.RECOVERY, true)
	queue_redraw()

func _on_action_ended(_action: String, _cancelled: bool) -> void:
	_shot_pending = false
	if is_instance_valid(_pending_area):
		_pending_area.queue_free()
	_pending_area = null
	_dodge_direction = Vector2.ZERO
	_dodge_moved_time = 0.0
	if is_instance_valid(navigator):
		navigator.stop()
	if is_instance_valid(state_machine):
		state_machine.transition(MuggStateMachine.State.DEAD if is_dying else MuggStateMachine.State.IDLE, true)
	_decision_timer = decision_interval
	queue_redraw()

func stun(duration: float = 0.3) -> void:
	if is_dying:
		return
	begin_action("damage", "damage_" + facing_direction, maxf(0.01, duration))
	state_machine.transition(MuggStateMachine.State.STUNNED, true)
	queue_redraw()

func _play_damage_animation() -> void:
	_recent_damage = 2.0
	# Ordinary hits still deal damage/flash, but cannot erase a telegraph or
	# recovery window. Explicit stun() and death can interrupt committed actions.
	if not state_machine.is_committed() and (not kiting_enabled or kite_hit_stagger):
		stun(0.2)

func _play_attack_animation() -> void:
	# Contact damage is passive; only the tree starts committed boss attacks.
	pass

func _draw() -> void:
	if not is_instance_valid(state_machine):
		return
	if state_machine.state == MuggStateMachine.State.DODGE:
		draw_line(Vector2.ZERO, -_dodge_direction * 35.0, Color(0.3, 0.9, 1.0), 4.0)
	elif state_machine.state == MuggStateMachine.State.WINDUP:
		var progress := clampf(action_elapsed / maxf(_active_windup, 0.1), 0.0, 1.0)
		var warning_color := homing_color if action_state == "homing_shot" else (Color(0.15, 0.9, 1.0) if action_state == "running_shot" else Color(1, 0.7, 0.1))
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU * progress, 32, warning_color, 3.0)
		draw_line(_locked_aim * 22.0, _locked_aim * 65.0, warning_color, 3.0)
	elif state_machine.state == MuggStateMachine.State.RECOVERY:
		draw_arc(Vector2.ZERO, 22.0, 0, TAU, 32, Color(0.5, 0.8, 1, 0.6), 1.0)
	if debug_ai and is_instance_valid(navigator):
		var previous := Vector2.ZERO
		for point in navigator.path:
			var local := to_local(point)
			draw_line(previous, local, Color(0.9, 0.9, 0.3, 0.6), 1.0)
			previous = local

func _varied_cooldown(base: float) -> float:
	return maxf(0.0, base * _rng.randf_range(1.0 - cooldown_variation, 1.0 + cooldown_variation))

func ai_choose_offense() -> DecisionNode.Status:
	if _offense_timer > 0.0 or not can_basic_shot():
		return DecisionNode.Status.FAILURE
	_offense_timer = tactic_choice_interval
	var options: Array[String] = ["basic_shot", "cluster_shot", "homing_shot", "running_shot", "move"]
	var weights: Array[float] = [maxf(0, basic_shot_weight), maxf(0, cluster_weight), homing_selection_weight(), maxf(0, running_shot_weight) if kiting_enabled else 0.0, maxf(0, tactical_move_weight)]
	var aggression := health_aggression()
	var defense := health_defense()
	for i in range(3):
		weights[i] *= lerpf(1.0, low_player_attack_weight_boost, aggression) * lerpf(1.0, 0.6, defense)
	weights[3] *= lerpf(1.0, low_player_attack_weight_boost, aggression) * lerpf(1.0, 2.0, defense)
	weights[4] *= lerpf(1.0, low_boss_movement_weight_boost, defense) * lerpf(1.0, 0.5, aggression)
	var total := 0.0
	for weight in weights:
		total += weight
	if total <= 0.0:
		return DecisionNode.Status.FAILURE
	var pick := _rng.randf() * total
	for i in options.size():
		pick -= weights[i]
		if weights[i] <= 0 or pick >= 0:
			continue
		if options[i] != "move":
			return ai_basic_shot(options[i])
		var result := ai_reposition("Tactical feint")
		if result == DecisionNode.Status.FAILURE and basic_shot_weight > 0:
			return ai_basic_shot()
		return result
	return DecisionNode.Status.FAILURE

func homing_selection_weight() -> float:
	if _homing_timer > 0:
		return 0.0
	var distance_factor := clampf((blackboard.distance - homing_near_distance) / maxf(1.0, homing_far_distance - homing_near_distance), 0, 1)
	return maxf(0, lerpf(homing_near_weight, homing_far_weight, distance_factor))

func _fire_selected_shot() -> void:
	if action_state == "running_shot":
		var ball := MuggBall.new()
		ball.ball_radius = 5.0
		ball.ball_color = Color(0.15, 0.9, 1.0)
		ball.speed = running_shot_speed
		ball.damage = projectile_damage
		ball.lifetime = 2.3
		get_parent().add_child(ball)
		ball.global_position = global_position + _locked_aim * minf(22, global_position.distance_to(_locked_target) * 0.5)
		ball.launch(_locked_aim)
		blackboard.shots_fired += 1
		return
	if action_state == "basic_shot":
		var shot := projectile_scene.instantiate()
		shot.damage = projectile_damage
		shot.speed = projectile_speed
		get_parent().add_child(shot)
		shot.global_position = global_position + _locked_aim * minf(28.0, global_position.distance_to(_locked_target) * 0.5)
		shot.launch(_locked_aim, Vector2.ZERO)
		blackboard.shots_fired += 1
		return
	var count := maxi(1, cluster_count) if action_state == "cluster_shot" else 1
	for i in count:
		var ball := MuggBall.new()
		var direction := _locked_aim
		if action_state == "cluster_shot":
			var sector := deg_to_rad(cluster_cone_degrees) / count
			var angle := -deg_to_rad(cluster_cone_degrees) / 2 + sector * (i + 0.5)
			angle += _rng.randf_range(-0.5, 0.5) * sector * cluster_scatter
			direction = direction.rotated(angle)
			ball.speed = cluster_speed * _rng.randf_range(1 - cluster_speed_variation, 1 + cluster_speed_variation)
			ball.damage = cluster_damage
			ball.lifetime = cluster_lifetime
		else:
			ball.homing = true
			ball.ball_radius = 6.0
			ball.ball_color = homing_color
			ball.speed = homing_speed
			ball.damage = homing_damage
			ball.lifetime = homing_lifetime
			ball.target = player
			ball.arena = arena
			ball.turn_rate_degrees = homing_turn_rate
			ball.tracking_duration = homing_tracking_duration
			ball.tracking_delay = homing_tracking_delay
		var muzzle := global_position + direction * minf(28.0, global_position.distance_to(_locked_target) * 0.5)
		# Individual fan pellets cannot spawn on the far side of nearby cover.
		if not has_clear_shot(global_position, muzzle):
			ball.free()
			continue
		get_parent().add_child(ball)
		ball.global_position = muzzle
		ball.launch(direction)
		blackboard.shots_fired += 1

func _incoming_threat(include_considered: bool = false) -> Projectile:
	var live_ids: Dictionary = {}
	var best: Projectile
	var earliest := INF
	for node in get_tree().get_nodes_in_group("projectiles"):
		if not node is Projectile or node.is_queued_for_deletion():
			continue
		var shot := node as Projectile
		var id := shot.get_instance_id()
		live_ids[id] = true
		if shot.has_landed or (not include_considered and _considered_projectiles.has(id)):
			continue
		var offset := shot.global_position - global_position
		if offset.length() > dodge_detection_range:
			continue
		var relative_velocity := shot.velocity - velocity
		if relative_velocity.length_squared() < 1.0:
			continue
		var time := -offset.dot(relative_velocity) / relative_velocity.length_squared()
		if time < 0.0 or time > minf(dodge_lookahead, shot.lifetime - shot.elapsed):
			continue
		if (offset + relative_velocity * time).length() > dodge_threat_radius:
			continue
		if not arena.has_clear_sight(global_position, shot.global_position):
			continue
		if not has_clear_shot(shot.global_position, shot.global_position + shot.velocity * time):
			continue
		if time < earliest:
			earliest = time
			best = shot
	for id in _considered_projectiles.keys():
		if not live_ids.has(id):
			_considered_projectiles.erase(id)
	return best

func ai_dodge() -> DecisionNode.Status:
	# Attacks/recovery cannot be escaped by dodging. Danger can interrupt walking.
	if not dodge_enabled or is_dying or action_state != "" or state_machine.is_committed() or _dodge_timer > 0.0:
		return DecisionNode.Status.FAILURE
	if not is_instance_valid(arena) or not navigator.ready_for_paths:
		return DecisionNode.Status.FAILURE
	var threat := _incoming_threat()
	if threat == null:
		return DecisionNode.Status.FAILURE
	_considered_projectiles[threat.get_instance_id()] = true
	if _rng.randf() >= effective_dodge_chance():
		return DecisionNode.Status.FAILURE
	var incoming := threat.velocity.normalized()
	var left := incoming.orthogonal()
	var away := threat.global_position.direction_to(global_position)
	var directions: Array[Vector2] = [left, -left, away, (away + left).normalized(), (away - left).normalized()]
	var weights: Array[float] = [dodge_left_weight, dodge_right_weight, dodge_away_weight, dodge_diagonal_weight, dodge_diagonal_weight]
	var valid: Array[int] = []
	var total := 0.0
	for i in directions.size():
		if weights[i] <= 0.0 or directions[i].length_squared() < 0.5:
			continue
		var destination := global_position + directions[i] * dodge_speed * dodge_duration
		if navigator.segment_clear(global_position, destination):
			valid.append(i)
			total += weights[i]
	if valid.is_empty():
		return DecisionNode.Status.FAILURE
	var pick := _rng.randf() * total
	var chosen := directions[valid[-1]]
	for i in valid:
		pick -= weights[i]
		if pick <= 0.0:
			chosen = directions[i]
			break
	if begin_action("dodge", "", dodge_duration + dodge_recovery) < 0:
		return DecisionNode.Status.FAILURE
	navigator.stop()
	_dodge_direction = chosen
	_dodge_moved_time = 0.0
	_dodge_timer = maxf(_varied_cooldown(dodge_cooldown * effective_defense_cooldown_scale()), dodge_duration + dodge_recovery)
	_update_facing_direction(chosen)
	_play_run_animation()
	state_machine.transition(MuggStateMachine.State.DODGE, true)
	blackboard.last_decision = "Dodge"
	return DecisionNode.Status.RUNNING

func _update_dodge(delta: float) -> void:
	velocity = Vector2.ZERO
	if state_machine.state == MuggStateMachine.State.DODGE_RECOVERY:
		return
	var active_time := minf(action_elapsed, dodge_duration)
	var step_time := maxf(0.0, active_time - _dodge_moved_time)
	_dodge_moved_time = active_time
	if step_time > 0.0:
		var motion := _dodge_direction * dodge_speed * step_time
		if navigator.segment_clear(global_position, global_position + motion):
			velocity = motion / maxf(delta, 0.001)
		else:
			_dodge_moved_time = dodge_duration
	if action_elapsed >= dodge_duration or _dodge_moved_time >= dodge_duration:
		state_machine.transition(MuggStateMachine.State.DODGE_RECOVERY, true)
		sprite.stop()

func ai_take_cover() -> DecisionNode.Status:
	if not cover_enabled or _cover_timer > 0 or action_state != "" or not blackboard.has_last_seen:
		return DecisionNode.Status.FAILURE
	if health_defense() < 0.25 and _recent_damage <= 0 and _incoming_threat(true) == null:
		return DecisionNode.Status.FAILURE
	var source := blackboard.last_seen_position
	if not has_clear_shot(source, global_position):
		return DecisionNode.Status.FAILURE
	var best := PackedVector2Array()
	var best_length := cover_search_distance
	for obstacle in get_tree().get_nodes_in_group("projectile_blockers"):
		if not obstacle is ArenaObstacle or not arena.is_ancestor_of(obstacle):
			continue
		var rect: Rect2 = obstacle.global_transform * Rect2(-obstacle.obstacle_size / 2, obstacle.obstacle_size)
		for i in 8:
			var direction := Vector2.from_angle(TAU * i / 8.0)
			var extent := rect.size / 2 + Vector2.ONE * (navigation_radius + 10)
			var candidate := rect.get_center() + direction * extent
			if candidate.distance_to(global_position) < 18 or candidate.distance_to(global_position) > best_length:
				continue
			if has_clear_shot(source, candidate):
				continue
			var route := navigator.path_to(global_position, candidate)
			if route.is_empty():
				continue
			var length := 0.0
			var previous := global_position
			for point in route:
				length += previous.distance_to(point)
				previous = point
			if length < best_length:
				best_length = length
				best = route
	if best.is_empty():
		return DecisionNode.Status.FAILURE
	navigator.set_path(best)
	state_machine.transition(MuggStateMachine.State.TAKE_COVER)
	_cover_timer = cover_cooldown * effective_defense_cooldown_scale()
	blackboard.last_decision = "Take cover from fire"
	return DecisionNode.Status.RUNNING

func ai_area_attack() -> DecisionNode.Status:
	if not area_enabled or is_dying or action_state != "" or _area_timer > 0 or _area_choice_timer > 0 or not blackboard.has_last_seen:
		return DecisionNode.Status.FAILURE
	if blackboard.distance > area_range:
		return DecisionNode.Status.FAILURE
	var anti_cover := _blocked_duration >= area_cover_delay
	var defensive := blackboard.player_visible and blackboard.distance < area_defensive_distance
	if not anti_cover and not defensive:
		return DecisionNode.Status.FAILURE
	_area_choice_timer = area_choice_interval
	var area_chance := area_anti_cover_chance if anti_cover else area_defensive_chance
	area_chance = lerpf(area_chance, 1.0, health_aggression() if anti_cover else health_defense())
	if _rng.randf() >= area_chance:
		return DecisionNode.Status.FAILURE
	# Lock a known position. This overhead attack bypasses blocks, not perception.
	var target := arena.clamp_to_arena(blackboard.last_seen_position, area_radius + 8)
	if begin_action("area_attack", "", area_warning + area_recovery) < 0:
		return DecisionNode.Status.FAILURE
	navigator.stop()
	_pending_area = MuggAreaAttack.new()
	_pending_area.radius = area_radius
	_pending_area.damage = area_damage
	_pending_area.duration = area_lifetime
	add_child(_pending_area)
	_pending_area.top_level = true
	_pending_area.global_position = target
	_area_timer = maxf(_varied_cooldown(area_cooldown), area_warning + area_lifetime)
	state_machine.transition(MuggStateMachine.State.AREA_WINDUP, true)
	blackboard.last_decision = "Flush cover" if anti_cover else "Defensive area attack"
	blackboard.last_attack = "Area denial"
	return DecisionNode.Status.RUNNING

func _try_hold_cover() -> bool:
	if state_machine.state != MuggStateMachine.State.TAKE_COVER or not navigator.path.is_empty():
		return false
	if not blackboard.has_last_seen or has_clear_shot(blackboard.last_seen_position, global_position):
		return false
	begin_action("cover_hold", "", cover_hold_duration * lerpf(1.0, low_boss_cover_hold_boost, health_defense()))
	state_machine.transition(MuggStateMachine.State.COVER_HOLD, true)
	blackboard.last_decision = "Hold cover briefly"
	return true

func _start_kiting() -> DecisionNode.Status:
	if not blackboard.has_last_seen or state_machine.is_committed():
		return DecisionNode.Status.FAILURE
	navigator.stop()
	state_machine.transition(MuggStateMachine.State.KITE)
	blackboard.last_decision = "Kite: retreat" if blackboard.distance < effective_preferred_distance() - kite_spacing_tolerance else "Kite: circle"
	return DecisionNode.Status.RUNNING

func _kite_velocity(delta: float) -> Vector2:
	if not kiting_enabled or not blackboard.has_last_seen or not is_instance_valid(arena) or not navigator.ready_for_paths:
		return Vector2.ZERO
	if _kite_side_timer <= 0:
		_kite_side_timer = maxf(0.2, kite_direction_interval) * _rng.randf_range(0.8, 1.2)
		if _rng.randf() < kite_reverse_chance:
			_kite_side *= -1
	if _kite_steer_timer <= 0 or _kite_direction == Vector2.ZERO:
		_kite_steer_timer = 0.12
		var away := blackboard.last_seen_position.direction_to(global_position)
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
		var tangent := away.orthogonal() * _kite_side
		var spacing := clampf((effective_preferred_distance() - blackboard.distance) / maxf(1, kite_spacing_tolerance), -1, 1)
		var desired := (away * spacing * kite_spacing_weight + tangent * kite_strafe_weight).normalized()
		var best_score := -INF
		_kite_direction = Vector2.ZERO
		var threat := _incoming_threat(true)
		for i in 24:
			var direction := Vector2.from_angle(TAU * i / 24.0)
			var endpoint := global_position + direction * maxf(kite_probe_distance, move_speed * delta)
			if not navigator.segment_clear(global_position, endpoint):
				continue
			var score := direction.dot(desired) * 3.0
			var distance_error := absf(endpoint.distance_to(blackboard.last_seen_position) - effective_preferred_distance())
			score -= distance_error / maxf(effective_preferred_distance(), 1)
			if arena.has_clear_sight(endpoint, blackboard.last_seen_position) and has_clear_shot(endpoint, blackboard.last_seen_position):
				score += 1.0
			# Prefer interior escape routes instead of retreating into a corner.
			var bounds := navigator.bounds
			var edge := minf(minf(endpoint.x - bounds.position.x, bounds.end.x - endpoint.x), minf(endpoint.y - bounds.position.y, bounds.end.y - endpoint.y))
			score += clampf(edge / 60.0, 0, 1) * 0.8
			if threat != null:
				var relative := threat.global_position - global_position
				var relative_speed := threat.velocity - direction * move_speed
				var time := clampf(-relative.dot(relative_speed) / maxf(relative_speed.length_squared(), 1), 0, dodge_lookahead)
				if (relative + relative_speed * time).length() < dodge_threat_radius:
					score -= 4.0
			if score > best_score:
				best_score = score
				_kite_direction = direction
	var motion := _kite_direction * move_speed * delta
	if not navigator.segment_clear(global_position, global_position + motion):
		_kite_direction = Vector2.ZERO
		_kite_steer_timer = 0
		return Vector2.ZERO
	return _kite_direction * move_speed

func health_defense() -> float:
	if not health_tactics_enabled or is_dying:
		return 0.0
	var ratio := clampf(health / maxf(max_health, 1.0), 0, 1)
	return clampf(1.0 - ratio / maxf(boss_low_health_threshold, 0.01), 0, 1)

func health_aggression() -> float:
	if not health_tactics_enabled or is_dying:
		return 0.0
	var urgency := clampf(1.0 - _observed_player_health_ratio / maxf(player_low_health_threshold, 0.01), 0, 1)
	# When both are wounded, self-preservation takes priority progressively.
	return urgency * (1.0 - health_defense())

func effective_preferred_distance() -> float:
	return clampf(preferred_distance + low_boss_extra_distance * health_defense() - low_player_close_in_distance * health_aggression(), close_distance + 10.0, maxf(close_distance + 10.0, attack_range - 25.0))

func effective_attack_cooldown_scale() -> float:
	return lerpf(1.0, low_player_cooldown_scale, health_aggression())

func effective_defense_cooldown_scale() -> float:
	return lerpf(1.0, low_boss_defense_cooldown_scale, health_defense())

func effective_dodge_chance() -> float:
	return clampf(dodge_chance + low_boss_dodge_bonus * health_defense(), 0, 1)
