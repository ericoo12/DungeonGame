extends Node
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func frames(count: int = 2) -> void:
	for i in count:
		await get_tree().physics_frame
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var room: RoomController = load("res://scenes/rooms/RoomBase.tscn").instantiate()
	room.scale = Vector2(2, 2)
	# Test-only obstacles; the playable boss arena intentionally remains open.
	for entry in [["GreenBlock", Vector2(-85,25)], ["BlueBlock", Vector2(85,25)]]:
		var obstacle = load("res://scenes/rooms/obstacles/" + entry[0] + ".tscn").instantiate()
		obstacle.position = entry[1]
		room.add_child(obstacle)
	add_child(room)
	var boss: DoktorMugg = load("res://scenes/enemies/bosses/DoktorMugg.tscn").instantiate()
	boss.process_mode = Node.PROCESS_MODE_PAUSABLE
	boss.random_seed = 123
	boss.running_shot_weight = 0
	boss.cluster_weight = 0
	boss.homing_near_weight = 0
	boss.homing_far_weight = 0
	boss.tactical_move_weight = 0
	boss.spawn_grace_period = 0
	boss.position = Vector2(-270, 50)
	add_child(boss)
	boss.set_physics_process(false)
	var target := Node2D.new()
	add_child(target)
	boss.player = target
	boss.set_arena(room)
	target.position = Vector2(-70, 50)
	await frames()
	boss.navigator.rebuild()
	boss._update_perception(0.1)
	check(boss.blackboard.player_visible, "Green obstacle preserves sight")
	check(boss.blackboard.shot_clear, "Shots pass over green obstacle")
	check(not boss.navigator.position_clear(Vector2(-170,50)), "Green still blocks movement")
	check(room.get_arena_bounds().size == Vector2(864,448), "Navigation uses transformed room bounds")
	var route := boss.navigator.path_to(boss.position, target.position)
	check(not route.is_empty(), "Path exists around green block")
	var safe := true
	var previous := boss.position
	for point in route:
		safe = safe and boss.navigator.segment_clear(previous, point)
		previous = point
	check(safe, "Every path segment has full body clearance")
	check(boss.navigator.path_to(boss.position, Vector2(-170,50)).is_empty(), "Reject destination inside obstacle")
	check(boss.navigator.path_to(boss.position, Vector2(900,0)).is_empty(), "Reject destination outside arena")
	boss.position = Vector2(70,50)
	target.position = Vector2(90,-60)
	boss._update_perception(0.1)
	var remembered := boss.blackboard.last_seen_position
	target.position = Vector2(270,50)
	boss._update_perception(0.1)
	check(not boss.blackboard.player_visible, "Blue obstacle blocks sight")
	check(boss.blackboard.has_last_seen and boss.blackboard.last_seen_position == remembered, "Hidden player does not update memory")
	boss._update_perception(boss.memory_duration + 0.1)
	check(not boss.blackboard.has_last_seen, "Memory expires")
	boss.behavior_tree.tick()
	check(boss.state_machine.state == MuggStateMachine.State.IDLE, "No observation returns idle")
	boss.position = Vector2(0,-70)
	target.position = Vector2(150,-70)
	boss._update_perception(0.1)
	boss.behavior_tree.tick()
	check(boss.action_state == "basic_shot", "Clear opportunity selects Basic Shot")
	check(boss.state_machine.state == MuggStateMachine.State.WINDUP, "Attack begins in windup")
	var aim := boss._locked_aim
	target.position = Vector2(0,80)
	boss._update_perception(0.1)
	boss.behavior_tree.tick()
	check(boss._locked_aim == aim and boss.action_elapsed == 0, "Tree does not restart or reaim committed attack")
	var hp := boss.health
	boss.take_damage(1)
	check(boss.health == hp - 1 and boss.action_state == "basic_shot", "Ordinary damage does not erase telegraph")
	boss._advance_action(boss.windup_duration + 0.01)
	check(boss.blackboard.shots_fired == 1, "Attack fires once after windup")
	boss._advance_action(boss.fire_duration)
	check(boss.state_machine.state == MuggStateMachine.State.RECOVERY, "Shot enters recovery")
	boss.take_damage(1)
	check(boss.action_state == "basic_shot", "Ordinary damage preserves recovery")
	boss._advance_action(boss.recovery_duration + 0.1)
	check(boss.action_state == "" and boss.blackboard.shots_fired == 1, "Recovery ends without repeat shot")
	boss._shot_cooldown = 0
	target.position = Vector2(150,-70)
	boss._update_perception(0.1)
	boss.ai_basic_shot()
	boss.stun(0.2)
	check(not boss._shot_pending and boss.state_machine.state == MuggStateMachine.State.STUNNED, "Explicit stun cancels pending shot")
	boss._advance_action(2)
	check(boss.blackboard.shots_fired == 1, "Cancelled attack never fires later")
	boss._shot_cooldown = 0
	boss.ai_basic_shot()
	boss.set_physics_process(true)
	get_tree().paused = true
	await get_tree().create_timer(0.15, true).timeout
	check(boss.action_elapsed == 0, "Pause freezes boss windup")
	get_tree().paused = false
	boss.set_physics_process(false)
	boss.cancel_action()
	boss.position = Vector2(-270,50)
	target.position = Vector2(-70,50)
	boss._shot_cooldown = 100
	boss._update_perception(0.1)
	boss.behavior_tree.tick()
	check(not boss.navigator.path.is_empty() or boss.state_machine.state == MuggStateMachine.State.KITE, "Shot cooldown selects movement or kiting")
	var start := boss.position
	boss.set_physics_process(true)
	await frames(100)
	boss.set_physics_process(false)
	check(boss.position.distance_to(start) > 30, "Boss navigates during real physics frames")
	check(boss.navigator.position_clear(boss.position), "Movement stays clear of obstacles and arena edge")
	boss.cancel_action()
	boss._shot_cooldown = 0
	boss.position = Vector2(0,-70)
	target.position = Vector2(150,-70)
	boss._update_perception(0.1)
	boss.ai_basic_shot()
	var fired := boss.blackboard.shots_fired
	boss.take_damage(10000)
	check(boss.is_dying and not boss._shot_pending and boss.state_machine.state == MuggStateMachine.State.DEAD, "Death cancels windup and enters terminal state")
	boss._advance_action(2)
	check(boss.blackboard.shots_fired == fired, "Death prevents delayed shot")
	var fallback := DecisionNode.selector([DecisionNode.condition(func(): return false), DecisionNode.action(func(): return DecisionNode.Status.RUNNING)])
	check(fallback.tick() == DecisionNode.Status.RUNNING, "Selector falls through failed branch and preserves running")
	print("MUGG AI: ", checks, " checks; ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
