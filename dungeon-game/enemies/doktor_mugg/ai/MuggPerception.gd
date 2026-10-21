extends RefCounted
class_name MuggPerception

## OBSERVE: sight, shot clearance and incoming projectile prediction. Never chooses an action.
var actor: Node

func _init(boss: Node) -> void:
	actor = boss

func _update_perception(delta: float) -> void:
	var previously_visible = actor.blackboard.player_visible
	var previous_observation = actor.blackboard.last_seen_position
	actor.blackboard.player_visible = false
	actor.blackboard.shot_clear = false
	if not is_instance_valid(actor.player) or (actor.player is Player and actor.player.is_dying):
		actor.blackboard.forget()
		return
	# Current position is used ONLY to determine visibility. Hidden-player
	# tactics and distances below use the stored observation, never live tracking.
	if actor.arena.has_clear_sight(actor.global_position, actor.player.global_position):
		actor._observed_player_velocity = (actor.player.global_position - previous_observation) / maxf(delta, 0.001) if previously_visible else Vector2.ZERO
		actor._observed_player_velocity = actor._observed_player_velocity.limit_length(250.0)
		if actor.player is Player:
			actor._observed_player_health_ratio = clampf(float(actor.player.current_hearts) / maxf(actor.player.max_hearts, 1), 0, 1)
		actor.blackboard.player_visible = true
		actor.blackboard.has_last_seen = true
		actor.blackboard.last_seen_position = actor.player.global_position
		actor.blackboard.time_since_seen = 0.0
		actor.blackboard.shot_clear = actor.has_clear_shot(actor.global_position, actor.player.global_position)
	else:
		actor._observed_player_velocity = Vector2.ZERO
		actor.blackboard.time_since_seen += delta
		if actor.blackboard.time_since_seen > actor.memory_duration:
			actor.blackboard.has_last_seen = false
	actor.blackboard.distance = actor.global_position.distance_to(actor.blackboard.last_seen_position) if actor.blackboard.has_last_seen else INF

func has_clear_shot(from: Vector2, to: Vector2) -> bool:
	# Swept projectile footprint, separate from movement and sight blockers.
	var shape = CircleShape2D.new()
	shape.radius = 9.0
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, from)
	query.collision_mask = 1 | (1 << 8)
	var space = actor.get_world_2d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	query.motion = to - from
	return space.cast_motion(query)[0] >= 0.999

func _incoming_threat(include_considered: bool = false) -> Projectile:
	var live_ids: Dictionary = {}
	var best: Projectile
	var earliest = INF
	for node in actor.get_tree().get_nodes_in_group("projectiles"):
		if not node is Projectile or node.is_queued_for_deletion():
			continue
		var shot = node as Projectile
		var id = shot.get_instance_id()
		live_ids[id] = true
		if shot.has_landed or (not include_considered and actor._considered_projectiles.has(id)):
			continue
		var offset = shot.global_position - actor.global_position
		if offset.length() > actor.dodge_detection_range:
			continue
		var relative_velocity = shot.velocity - actor.velocity
		if relative_velocity.length_squared() < 1.0:
			continue
		var time = -offset.dot(relative_velocity) / relative_velocity.length_squared()
		if time < 0.0 or time > minf(actor.dodge_lookahead, shot.lifetime - shot.elapsed):
			continue
		if (offset + relative_velocity * time).length() > actor.dodge_threat_radius:
			continue
		if not actor.arena.has_clear_sight(actor.global_position, shot.global_position):
			continue
		if not actor.has_clear_shot(shot.global_position, shot.global_position + shot.velocity * time):
			continue
		if time < earliest:
			earliest = time
			best = shot
	for id in actor._considered_projectiles.keys():
		if not live_ids.has(id):
			actor._considered_projectiles.erase(id)
	return best

