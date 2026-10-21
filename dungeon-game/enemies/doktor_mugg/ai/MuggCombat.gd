extends RefCounted
class_name MuggCombat

## EXECUTE: start actions and advance windup, release, recovery and cancellation.
var actor: Node

func _init(boss: Node) -> void:
	actor = boss

func can_basic_shot() -> bool:
	return actor.projectile_scene != null and actor._shot_cooldown <= 0.0 and actor.blackboard.player_visible and actor.blackboard.shot_clear and actor.blackboard.distance <= actor.attack_range

## All four projectile attacks share the same three FSM phases.
func start_projectile_attack(kind: String = "basic_shot") -> DecisionNode.Status:
	if not actor.can_basic_shot() or actor.state_machine.is_committed() or actor.is_dying:
		return DecisionNode.Status.FAILURE
	var profile = _shot_profile(kind)
	actor.navigator.stop()
	actor._locked_target = actor.blackboard.last_seen_position
	if kind != "homing_shot" and actor.aim_lead_strength > 0:
		var flight_time = actor.blackboard.distance / maxf(1, profile.speed)
		var lead = actor._observed_player_velocity * flight_time * actor.aim_lead_strength
		actor._locked_target += lead.limit_length(actor.aim_lead_max_distance)
	actor._locked_aim = actor.global_position.direction_to(actor._locked_target)
	actor._update_facing_direction(actor._locked_aim)
	actor._active_windup = maxf(0.05, profile.windup)
	actor._active_recovery = profile.recovery
	var duration = actor._active_windup + actor.fire_duration + actor._active_recovery
	# Gameplay timing is independent of the temporary animation's length.
	if actor.begin_action(kind, "", duration) < 0:
		return DecisionNode.Status.FAILURE
	actor.sprite.play("attack_" + actor.facing_direction)
	actor.sprite.pause()
	actor.state_machine.transition(MuggStateMachine.State.WINDUP, true)
	actor._shot_pending = true
	var cooldown = actor._varied_cooldown(profile.cooldown * actor.effective_attack_cooldown_scale())
	actor._shot_cooldown = maxf(cooldown, duration)
	actor.blackboard.last_attack = profile.title
	actor.blackboard.last_decision = profile.title
	if kind == "homing_shot":
		actor._homing_timer = maxf(actor.homing_cooldown, duration)
	actor.queue_redraw()
	return DecisionNode.Status.RUNNING

## Only the values that differ between projectile attacks live here.
func _shot_profile(kind: String) -> Dictionary:
	var profile = {
		"title": "Basic Shot", "windup": actor.windup_duration,
		"recovery": actor.recovery_duration, "cooldown": actor.attack_cooldown,
		"speed": actor.projectile_speed
	}
	match kind:
		"cluster_shot":
			profile.title = "Cluster Shot"
			profile.windup = actor.cluster_windup
			profile.speed = actor.cluster_speed
		"homing_shot":
			profile.title = "Homing Shot"
			profile.windup = actor.homing_windup
			profile.speed = actor.homing_speed
		"running_shot":
			profile.title = "Running Shot"
			profile.windup = actor.running_shot_windup
			profile.recovery = actor.running_shot_recovery
			profile.cooldown = actor.running_shot_cooldown
			profile.speed = actor.running_shot_speed
	return profile

func advance_action(_delta: float) -> void:
	if actor.action_state == "cover_hold":
		if actor.blackboard.player_visible and actor.has_clear_shot(actor.blackboard.last_seen_position, actor.global_position):
			actor.cancel_action()
		return
	if actor.action_state == "area_attack":
		if is_instance_valid(actor._pending_area):
			actor._pending_area.warning_progress = clampf(actor.action_elapsed / actor.area_warning, 0, 1)
			actor._pending_area.queue_redraw()
			if actor.action_elapsed >= actor.area_warning:
				actor._pending_area.arm()
				actor._pending_area = null
				actor.state_machine.transition(MuggStateMachine.State.AREA_RECOVERY, true)
		return
	if actor.action_state == "dodge" and not actor.is_dying:
		actor._update_dodge(_delta)
		return
	if actor.is_dying or actor.action_state not in ["basic_shot", "cluster_shot", "homing_shot", "running_shot"]:
		return
	if actor.kiting_enabled:
		if actor.action_state == "running_shot":
			actor.velocity = actor._kite_velocity(_delta)
		elif actor.action_elapsed < actor._active_windup - actor.kite_plant_window:
			actor.velocity = actor._kite_velocity(_delta) * actor.kite_windup_speed
		elif actor.action_elapsed >= actor._active_windup + actor.fire_duration:
			actor.velocity = actor._kite_velocity(_delta) * actor.kite_recovery_speed
	if actor.action_elapsed >= actor._active_windup and actor._shot_pending:
		actor._shot_pending = false
		actor.state_machine.transition(MuggStateMachine.State.FIRE, true)
		actor.sprite.play("attack_" + actor.facing_direction)
		# Commit to the original direction, never re-aim at a hidden/moving player.
		if actor.has_clear_shot(actor.global_position, actor.global_position + actor._locked_aim * actor.global_position.distance_to(actor._locked_target)):
			actor._fire_selected_shot()
	if actor.action_elapsed >= actor._active_windup + actor.fire_duration:
		actor.state_machine.transition(MuggStateMachine.State.RECOVERY, true)
	actor.queue_redraw()

func cleanup_action(_action: String, _cancelled: bool) -> void:
	actor._shot_pending = false
	if is_instance_valid(actor._pending_area):
		actor._pending_area.queue_free()
	actor._pending_area = null
	actor._dodge_direction = Vector2.ZERO
	actor._dodge_moved_time = 0.0
	if is_instance_valid(actor.navigator):
		actor.navigator.stop()
	if is_instance_valid(actor.state_machine):
		actor.state_machine.transition(MuggStateMachine.State.DEAD if actor.is_dying else MuggStateMachine.State.IDLE, true)
	actor._decision_timer = actor.decision_interval
	actor.queue_redraw()

func stun(duration: float = 0.3) -> void:
	if actor.is_dying:
		return
	actor.begin_action("damage", "damage_" + actor.facing_direction, maxf(0.01, duration))
	actor.state_machine.transition(MuggStateMachine.State.STUNNED, true)
	actor.queue_redraw()

func _play_damage_animation() -> void:
	actor._recent_damage = 2.0
	# Ordinary hits still deal damage/flash, but cannot erase a telegraph or
	# recovery window. Explicit stun() and death can interrupt committed actions.
	if not actor.state_machine.is_committed() and (not actor.kiting_enabled or actor.kite_hit_stagger):
		actor.stun(0.2)

func release_projectiles() -> void:
	if actor.action_state == "running_shot":
		var ball = MuggBall.new()
		ball.ball_radius = 5.0
		ball.ball_color = Color(0.15, 0.9, 1.0)
		ball.speed = actor.running_shot_speed
		ball.damage = actor.running_shot_damage
		ball.lifetime = 2.3
		actor.get_parent().add_child(ball)
		ball.global_position = actor.global_position + actor._locked_aim * minf(22, actor.global_position.distance_to(actor._locked_target) * 0.5)
		ball.launch(actor._locked_aim)
		actor.blackboard.shots_fired += 1
		return
	if actor.action_state == "basic_shot":
		var shot = MuggBall.new()
		shot.stained = true
		shot.ball_radius = 7.0
		shot.damage = actor.projectile_damage
		shot.speed = actor.projectile_speed
		actor.get_parent().add_child(shot)
		shot.global_position = actor.global_position + actor._locked_aim * minf(28.0, actor.global_position.distance_to(actor._locked_target) * 0.5)
		shot.launch(actor._locked_aim, Vector2.ZERO)
		actor.blackboard.shots_fired += 1
		return
	var count = maxi(1, actor.cluster_count) if actor.action_state == "cluster_shot" else 1
	for i in count:
		var ball = MuggBall.new()
		var direction = actor._locked_aim
		if actor.action_state == "cluster_shot":
			var sector = deg_to_rad(actor.cluster_cone_degrees) / count
			var angle = -deg_to_rad(actor.cluster_cone_degrees) / 2 + sector * (i + 0.5)
			angle += actor._rng.randf_range(-0.5, 0.5) * sector * actor.cluster_scatter
			direction = direction.rotated(angle)
			ball.speed = actor.cluster_speed * actor._rng.randf_range(1 - actor.cluster_speed_variation, 1 + actor.cluster_speed_variation)
			ball.damage = actor.cluster_damage
			ball.lifetime = actor.cluster_lifetime
		else:
			ball.homing = true
			ball.trail_damage = actor.paper_trail_damage
			ball.trail_lifetime = actor.paper_trail_lifetime
			ball.trail_width = actor.paper_trail_width
			ball.ball_radius = 6.0
			ball.ball_color = actor.homing_color
			ball.speed = actor.homing_speed
			ball.damage = actor.homing_damage
			ball.lifetime = actor.homing_lifetime
			ball.target = actor.player
			ball.arena = actor.arena
			ball.turn_rate_degrees = actor.homing_turn_rate
			ball.tracking_duration = actor.homing_tracking_duration
			ball.tracking_delay = actor.homing_tracking_delay
		var muzzle = actor.global_position + direction * minf(28.0, actor.global_position.distance_to(actor._locked_target) * 0.5)
		# Individual fan pellets cannot spawn on the far side of nearby cover.
		if not actor.has_clear_shot(actor.global_position, muzzle) or (ball.homing and not actor.navigator.segment_clear(actor.global_position, muzzle)):
			ball.free()
			continue
		actor.get_parent().add_child(ball)
		ball.global_position = muzzle
		ball.launch(direction)
		actor.blackboard.shots_fired += 1

func start_dodge(allow_retreat: bool = false) -> DecisionNode.Status:
	# Attacks/recovery cannot be escaped by dodging. Danger can interrupt walking.
	if not actor.dodge_enabled or actor.is_dying or actor.action_state != "" or actor.state_machine.is_committed() or actor._dodge_timer > 0.0:
		return DecisionNode.Status.FAILURE
	if not is_instance_valid(actor.arena) or not actor.navigator.ready_for_paths:
		return DecisionNode.Status.FAILURE
	var threat = actor._incoming_threat()
	if threat == null and (not allow_retreat or not actor.blackboard.player_visible):
		return DecisionNode.Status.FAILURE
	if threat != null:
		actor._considered_projectiles[threat.get_instance_id()] = true
	if actor._rng.randf() >= actor.effective_dodge_chance():
		return DecisionNode.Status.FAILURE
	var incoming = threat.velocity.normalized() if threat != null else actor.blackboard.last_seen_position.direction_to(actor.global_position)
	var left = incoming.orthogonal()
	var away = threat.global_position.direction_to(actor.global_position) if threat != null else incoming
	var directions: Array[Vector2] = [left, -left, away, (away + left).normalized(), (away - left).normalized()]
	var weights: Array[float] = [actor.dodge_left_weight, actor.dodge_right_weight, actor.dodge_away_weight, actor.dodge_diagonal_weight, actor.dodge_diagonal_weight]
	var valid: Array[int] = []
	var total = 0.0
	for i in directions.size():
		if weights[i] <= 0.0 or directions[i].length_squared() < 0.5:
			continue
		var destination = actor.global_position + directions[i] * actor.dodge_speed * actor.dodge_duration
		if actor.navigator.segment_clear(actor.global_position, destination):
			valid.append(i)
			total += weights[i]
	if valid.is_empty():
		return DecisionNode.Status.FAILURE
	var pick = actor._rng.randf() * total
	var chosen = directions[valid[-1]]
	for i in valid:
		pick -= weights[i]
		if pick <= 0.0:
			chosen = directions[i]
			break
	if actor.begin_action("dodge", "", actor.dodge_duration + actor.dodge_recovery) < 0:
		return DecisionNode.Status.FAILURE
	actor.navigator.stop()
	actor._dodge_direction = chosen
	actor._dodge_moved_time = 0.0
	actor._dodge_timer = maxf(actor._varied_cooldown(actor.dodge_cooldown * actor.effective_defense_cooldown_scale()), actor.dodge_duration + actor.dodge_recovery)
	actor._update_facing_direction(chosen)
	actor._play_run_animation()
	actor.state_machine.transition(MuggStateMachine.State.DODGE, true)
	actor.blackboard.last_decision = "Dodge"
	return DecisionNode.Status.RUNNING

func _update_dodge(delta: float) -> void:
	actor.velocity = Vector2.ZERO
	if actor.state_machine.state == MuggStateMachine.State.DODGE_RECOVERY:
		return
	var active_time = minf(actor.action_elapsed, actor.dodge_duration)
	var step_time = maxf(0.0, active_time - actor._dodge_moved_time)
	actor._dodge_moved_time = active_time
	if step_time > 0.0:
		var motion = actor._dodge_direction * actor.dodge_speed * step_time
		if actor.navigator.segment_clear(actor.global_position, actor.global_position + motion):
			actor.velocity = motion / maxf(delta, 0.001)
		else:
			actor._dodge_moved_time = actor.dodge_duration
	if actor.action_elapsed >= actor.dodge_duration or actor._dodge_moved_time >= actor.dodge_duration:
		actor.state_machine.transition(MuggStateMachine.State.DODGE_RECOVERY, true)
		actor.sprite.stop()

func start_area_attack() -> DecisionNode.Status:
	if not actor.area_enabled or actor.is_dying or actor.action_state != "" or actor._area_timer > 0 or actor._area_choice_timer > 0 or not actor.blackboard.has_last_seen:
		return DecisionNode.Status.FAILURE
	if actor.blackboard.distance > actor.area_range:
		return DecisionNode.Status.FAILURE
	var anti_cover = actor._blocked_duration >= actor.area_cover_delay
	var defensive = actor.blackboard.player_visible and actor.blackboard.distance < actor.area_defensive_distance
	if not anti_cover and not defensive:
		return DecisionNode.Status.FAILURE
	actor._area_choice_timer = actor.area_choice_interval
	var area_chance = actor.area_anti_cover_chance if anti_cover else actor.area_defensive_chance
	area_chance = lerpf(area_chance, 1.0, actor.health_aggression() if anti_cover else actor.health_defense())
	if actor._rng.randf() >= area_chance:
		return DecisionNode.Status.FAILURE
	# Lock a known position. This overhead attack bypasses blocks, not perception.
	var target = actor.arena.clamp_to_arena(actor.blackboard.last_seen_position, actor.area_radius + 8)
	if actor.begin_action("area_attack", "", actor.area_warning + actor.area_recovery) < 0:
		return DecisionNode.Status.FAILURE
	actor.navigator.stop()
	actor._pending_area = MuggAreaAttack.new()
	actor._pending_area.radius = actor.area_radius
	actor._pending_area.damage = actor.area_damage
	actor._pending_area.duration = actor.area_lifetime
	actor.add_child(actor._pending_area)
	actor._pending_area.top_level = true
	actor._pending_area.global_position = target
	actor._area_timer = maxf(actor._varied_cooldown(actor.area_cooldown), actor.area_warning + actor.area_lifetime)
	actor.state_machine.transition(MuggStateMachine.State.AREA_WINDUP, true)
	actor.blackboard.last_decision = "Flush cover" if anti_cover else "Defensive area attack"
	actor.blackboard.last_attack = "Area denial"
	return DecisionNode.Status.RUNNING

