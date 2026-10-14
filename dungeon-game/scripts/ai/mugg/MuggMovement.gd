extends RefCounted
class_name MuggMovement

## MOVE: route selection, cover destinations and kiting steering. Never calls move_and_slide.
var actor: Node

func _init(boss: Node) -> void:
	actor = boss

func movement_is_committed() -> bool:
	if actor.state_machine.state == MuggStateMachine.State.TAKE_COVER and not actor.navigator.path.is_empty():
		return true
	return actor.state_machine.state in [MuggStateMachine.State.PRESSURE, MuggStateMachine.State.REPOSITION, MuggStateMachine.State.TAKE_COVER] and actor.state_machine.elapsed < actor.movement_commitment and not actor.navigator.path.is_empty()

func ai_idle() -> DecisionNode.Status:
	actor.navigator.stop()
	actor.state_machine.transition(MuggStateMachine.State.IDLE)
	actor.blackboard.last_decision = "Wait for sight"
	return DecisionNode.Status.SUCCESS

func ai_reposition(reason: String) -> DecisionNode.Status:
	if actor.kiting_enabled and actor.blackboard.player_visible and reason == "Create distance":
		return actor._start_kiting()
	if actor._reposition_timer > 0.0 or actor._movement_retry > 0.0:
		return DecisionNode.Status.FAILURE
	var route = actor._choose_position(reason == "Create distance")
	if route.is_empty():
		actor._movement_retry = 0.3
		return DecisionNode.Status.FAILURE
	if not actor.state_machine.transition(MuggStateMachine.State.REPOSITION):
		return DecisionNode.Status.FAILURE
	actor.navigator.set_path(route)
	actor._reposition_timer = actor.movement_timeout + actor.reposition_cooldown
	actor.blackboard.last_decision = reason
	return DecisionNode.Status.RUNNING

func ai_pressure() -> DecisionNode.Status:
	if actor.kiting_enabled and actor.blackboard.player_visible and actor.blackboard.shot_clear:
		return actor._start_kiting()
	if actor.movement_is_committed():
		return DecisionNode.Status.RUNNING
	if not actor.blackboard.has_last_seen or actor._movement_retry > 0.0:
		return DecisionNode.Status.FAILURE
	# Reuse an active route until its time limit instead of rerolling each tick.
	if actor.state_machine.state in [MuggStateMachine.State.PRESSURE, MuggStateMachine.State.REPOSITION, MuggStateMachine.State.TAKE_COVER] and not actor.navigator.path.is_empty():
		return DecisionNode.Status.RUNNING
	var route = actor._choose_position(false)
	if route.is_empty():
		actor._movement_retry = 0.3
		return DecisionNode.Status.FAILURE
	actor.state_machine.transition(MuggStateMachine.State.PRESSURE)
	actor.navigator.set_path(route)
	actor.blackboard.last_decision = "Pressure" if actor.blackboard.player_visible else "Investigate last sighting"
	return DecisionNode.Status.RUNNING

func _choose_position(retreat: bool) -> PackedVector2Array:
	var routes: Array[PackedVector2Array] = []
	var weights: Array[float] = []
	var total = 0.0
	var target = actor.blackboard.last_seen_position
	var angle_offset = actor._rng.randf_range(0.0, TAU)
	for i in 16:
		var angle = angle_offset + TAU * float(i) / 16.0
		var distance = actor.effective_preferred_distance() * (0.8 if i % 2 == 0 else 1.15)
		var candidate = actor.arena.clamp_to_arena(target + Vector2.from_angle(angle) * distance, actor.navigation_radius + 8.0)
		if candidate.distance_to(actor.global_position) < 24.0:
			continue
		if retreat and candidate.distance_to(target) < actor.blackboard.distance + 20.0:
			continue
		var route = actor.navigator.path_to(actor.global_position, candidate)
		if route.is_empty():
			continue
		var clear_angle = actor.arena.has_clear_sight(candidate, target) and actor.has_clear_shot(candidate, target)
		var weight = actor.clear_position_weight if clear_angle else actor.blocked_position_weight
		if weight <= 0.0:
			continue
		weight /= 1.0 + actor.global_position.distance_to(candidate) / maxf(1.0, actor.position_distance_scale)
		routes.append(route)
		weights.append(weight)
		total += weight
	if routes.is_empty():
		return PackedVector2Array()
	var pick = actor._rng.randf() * total
	for i in routes.size():
		pick -= weights[i]
		if pick <= 0.0:
			return routes[i]
	return routes[-1]

func ai_take_cover() -> DecisionNode.Status:
	if not actor.cover_enabled or actor._cover_timer > 0 or actor.action_state != "" or not actor.blackboard.has_last_seen:
		return DecisionNode.Status.FAILURE
	if actor.health_defense() < actor.proactive_cover_defense_threshold and actor._recent_damage <= 0 and actor._incoming_threat(true) == null:
		return DecisionNode.Status.FAILURE
	var source = actor.blackboard.last_seen_position
	if not actor.has_clear_shot(source, actor.global_position):
		return DecisionNode.Status.FAILURE
	var best = PackedVector2Array()
	var best_length = actor.cover_search_distance
	for obstacle in actor.get_tree().get_nodes_in_group("projectile_blockers"):
		if not obstacle is ArenaObstacle or not actor.arena.is_ancestor_of(obstacle):
			continue
		var rect: Rect2 = obstacle.global_transform * Rect2(-obstacle.obstacle_size / 2, obstacle.obstacle_size)
		for i in 8:
			var direction = Vector2.from_angle(TAU * i / 8.0)
			var extent = rect.size / 2 + Vector2.ONE * (actor.navigation_radius + 10)
			var candidate = rect.get_center() + direction * extent
			if candidate.distance_to(actor.global_position) < 18 or candidate.distance_to(actor.global_position) > best_length:
				continue
			if actor.has_clear_shot(source, candidate):
				continue
			var route = actor.navigator.path_to(actor.global_position, candidate)
			if route.is_empty():
				continue
			var length = 0.0
			var previous = actor.global_position
			for point in route:
				length += previous.distance_to(point)
				previous = point
			if length < best_length:
				best_length = length
				best = route
	if best.is_empty():
		return DecisionNode.Status.FAILURE
	actor.navigator.set_path(best)
	actor.state_machine.transition(MuggStateMachine.State.TAKE_COVER)
	actor._cover_timer = actor.cover_cooldown * actor.effective_defense_cooldown_scale()
	actor.blackboard.last_decision = "Take cover from fire"
	return DecisionNode.Status.RUNNING

func _try_hold_cover() -> bool:
	if actor.state_machine.state != MuggStateMachine.State.TAKE_COVER or not actor.navigator.path.is_empty():
		return false
	if not actor.blackboard.has_last_seen or actor.has_clear_shot(actor.blackboard.last_seen_position, actor.global_position):
		return false
	actor.begin_action("cover_hold", "", actor.cover_hold_duration * lerpf(1.0, actor.low_boss_cover_hold_boost, actor.health_defense()))
	actor.state_machine.transition(MuggStateMachine.State.COVER_HOLD, true)
	actor.blackboard.last_decision = "Hold cover briefly"
	return true

func _start_kiting() -> DecisionNode.Status:
	if not actor.blackboard.has_last_seen or actor.state_machine.is_committed():
		return DecisionNode.Status.FAILURE
	actor.navigator.stop()
	actor.state_machine.transition(MuggStateMachine.State.KITE)
	actor.blackboard.last_decision = "Kite: retreat" if actor.blackboard.distance < actor.effective_preferred_distance() - actor.kite_spacing_tolerance else "Kite: circle"
	return DecisionNode.Status.RUNNING

func _kite_velocity(delta: float) -> Vector2:
	if not actor.kiting_enabled or not actor.blackboard.has_last_seen or not is_instance_valid(actor.arena) or not actor.navigator.ready_for_paths:
		return Vector2.ZERO
	if actor._kite_side_timer <= 0:
		actor._kite_side_timer = maxf(0.2, actor.kite_direction_interval) * actor._rng.randf_range(0.8, 1.2)
		if actor._rng.randf() < actor.kite_reverse_chance:
			actor._kite_side *= -1
	if actor._kite_steer_timer <= 0 or actor._kite_direction == Vector2.ZERO:
		actor._kite_steer_timer = 0.12
		var away = actor.blackboard.last_seen_position.direction_to(actor.global_position)
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
		var tangent = away.orthogonal() * actor._kite_side
		var spacing = clampf((actor.effective_preferred_distance() - actor.blackboard.distance) / maxf(1, actor.kite_spacing_tolerance), -1, 1)
		var desired = (away * spacing * actor.kite_spacing_weight + tangent * actor.kite_strafe_weight).normalized()
		var best_score = -INF
		actor._kite_direction = Vector2.ZERO
		var threat = actor._incoming_threat(true)
		for i in 24:
			var direction = Vector2.from_angle(TAU * i / 24.0)
			var endpoint = actor.global_position + direction * maxf(actor.kite_probe_distance, actor.move_speed * delta)
			if not actor.navigator.segment_clear(actor.global_position, endpoint):
				continue
			var score = direction.dot(desired) * 3.0
			var distance_error = absf(endpoint.distance_to(actor.blackboard.last_seen_position) - actor.effective_preferred_distance())
			score -= distance_error / maxf(actor.effective_preferred_distance(), 1)
			if actor.arena.has_clear_sight(endpoint, actor.blackboard.last_seen_position) and actor.has_clear_shot(endpoint, actor.blackboard.last_seen_position):
				score += 1.0
			# Prefer interior escape routes instead of retreating into a corner.
			var bounds = actor.navigator.bounds
			var edge = minf(minf(endpoint.x - bounds.position.x, bounds.end.x - endpoint.x), minf(endpoint.y - bounds.position.y, bounds.end.y - endpoint.y))
			score += clampf(edge / 60.0, 0, 1) * 0.8
			if threat != null:
				var relative = threat.global_position - actor.global_position
				var relative_speed = threat.velocity - direction * actor.move_speed
				var time = clampf(-relative.dot(relative_speed) / maxf(relative_speed.length_squared(), 1), 0, actor.dodge_lookahead)
				if (relative + relative_speed * time).length() < actor.dodge_threat_radius:
					score -= 4.0
			if score > best_score:
				best_score = score
				actor._kite_direction = direction
	var motion = actor._kite_direction * actor.move_speed * delta
	if not actor.navigator.segment_clear(actor.global_position, actor.global_position + motion):
		actor._kite_direction = Vector2.ZERO
		actor._kite_steer_timer = 0
		return Vector2.ZERO
	return actor._kite_direction * actor.move_speed


## Called once per free physics frame, after the tree has chosen a tactic.
func update_free_movement(delta: float) -> void:
	if actor.state_machine.state == MuggStateMachine.State.KITE:
		actor.velocity = actor._kite_velocity(delta)
		if actor.velocity == Vector2.ZERO:
			var escape = actor._choose_position(false)
			if not escape.is_empty():
				actor.navigator.set_path(escape)
				actor.state_machine.transition(MuggStateMachine.State.REPOSITION)
		if actor.velocity.length_squared() > 0.01:
			actor._update_facing_direction(actor.velocity.normalized())
		return
	if actor.state_machine.state in [MuggStateMachine.State.PRESSURE, MuggStateMachine.State.REPOSITION, MuggStateMachine.State.TAKE_COVER]:
		actor.velocity = actor.navigator.desired_velocity(actor.global_position, actor.move_speed, delta)
		if actor.velocity.length_squared() > 0.01:
			actor._update_facing_direction(actor.velocity.normalized())
			actor._stuck_time = actor._stuck_time + delta if actor.global_position.distance_to(actor._last_position) < 0.2 else 0.0
		else:
			actor._stuck_time = 0.0
		actor._last_position = actor.global_position
		if actor._try_hold_cover():
			return
		if actor.navigator.path.is_empty() or actor.state_machine.elapsed >= (actor.cover_search_distance / maxf(actor.move_speed, 1) + 0.5 if actor.state_machine.state == MuggStateMachine.State.TAKE_COVER else actor.movement_timeout) or actor._stuck_time > 0.4:
			actor.navigator.stop()
			actor.state_machine.transition(MuggStateMachine.State.IDLE)
			actor._decision_timer = 0.0
			actor._stuck_time = 0.0
