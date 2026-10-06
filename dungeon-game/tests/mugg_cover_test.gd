extends Node
var checks := 0
var failures := 0
class Target extends Node2D:
	var hits := 0
	func take_damage(_amount: float) -> void:
		hits += 1
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
	var room: RoomController = load("res://scenes/rooms/BoosRoom.tscn").instantiate()
	add_child(room)
	var boss: DoktorMugg = load("res://scenes/enemies/bosses/DoktorMugg.tscn").instantiate()
	boss.random_seed = 123
	boss.spawn_grace_period = 0
	boss.position = Vector2(120,-70)
	add_child(boss)
	boss.set_physics_process(false)
	boss.set_arena(room)
	var target := Target.new()
	add_child(target)
	target.add_to_group("player")
	target.position = Vector2(-250,-70)
	boss.player = target
	await frames()
	boss.navigator.rebuild()
	check(room.get_node("Obstacles").get_child_count() == 10, "Ten arena blocks")
	check(boss.navigator.position_clear(boss.position) and boss.navigator.position_clear(target.position), "Spawn positions have body clearance")
	for point in [Vector2(-350,0),Vector2(350,0),Vector2(0,-165),Vector2(0,165)]:
		check(not boss.navigator.path_to(boss.position,point).is_empty(), "Reachable arena region " + str(point))
	for block in room.get_node("Obstacles").get_children():
		if not block.blocks_sight:
			check(not block.is_in_group("projectile_blockers") and block.collision_layer == 128, "Green is movement-only and excluded from cover candidates")
		else:
			check(block.is_in_group("projectile_blockers") and block.collision_layer == 896, "Blue blocks movement, shots and sight")
	# Known threat to the east; the blue block at (240,0) offers nearby cover.
	boss.position = Vector2(200,70)
	target.position = Vector2(340,0)
	boss._update_perception(0.1)
	boss._recent_damage = 2
	check(boss.ai_take_cover() == DecisionNode.Status.RUNNING, "Under fire selects reachable cover")
	check(boss.state_machine.state == MuggStateMachine.State.TAKE_COVER, "Cover has explicit movement state")
	check(not boss.has_clear_shot(target.position,boss.navigator.goal), "Cover goal actually blocks shots")
	check(boss.movement_is_committed(), "Cover route is not replaced by ordinary offense")
	boss.position = boss.navigator.goal
	boss.navigator.stop()
	boss._update_behavior(0.01)
	check(boss.action_state == "cover_hold", "Arrival holds cover briefly")
	boss._advance_action(2)
	check(boss.action_state == "", "Cover hold ends instead of camping forever")
	boss._cover_timer = 0
	boss._recent_damage = 0
	check(boss.ai_take_cover() == DecisionNode.Status.FAILURE, "No threat does not trigger cover")
	boss.position = Vector2(0,0)
	target.position = Vector2(60,0)
	boss._update_perception(0.1)
	boss.area_defensive_chance = 1
	check(boss.ai_area_attack() == DecisionNode.Status.RUNNING, "Close player triggers defensive area attack")
	var warning := boss._pending_area
	var locked := warning.global_position
	warning._physics_process(0.5)
	check(target.hits == 0 and not warning.armed, "Warning does no damage")
	target.position = Vector2(160,0)
	boss._update_perception(0.1)
	check(warning.global_position == locked, "Area position remains fixed after player moves")
	boss.stun()
	check(boss._pending_area == null and warning.is_queued_for_deletion(), "Stun cancels unarmed warning")
	boss.cancel_action()
	boss._area_timer = 0
	boss._area_choice_timer = 0
	boss.blackboard.has_last_seen = true
	boss.blackboard.player_visible = false
	boss.blackboard.last_seen_position = Vector2(60,0)
	boss.blackboard.distance = 60
	boss._blocked_duration = 1
	boss.area_anti_cover_chance = 1
	check(boss.ai_area_attack() == DecisionNode.Status.RUNNING, "Remembered cover position triggers area denial")
	warning = boss._pending_area
	check(warning.global_position == Vector2(60,0), "Hidden live position is not used")
	boss._advance_action(boss.area_warning + 0.01)
	check(warning.armed and boss._pending_area == null, "Warning becomes active after delay")
	check(boss.state_machine.state == MuggStateMachine.State.AREA_RECOVERY, "Caster enters recovery")
	warning.set_physics_process(false)
	warning._physics_process(0.01)
	check(target.hits == 0, "Player outside radius is safe")
	target.position = warning.global_position
	warning._physics_process(0.4)
	check(target.hits == 1, "Player inside active area takes damage")
	boss._advance_action(2)
	check(boss.ai_area_attack() == DecisionNode.Status.FAILURE, "Area cooldown prevents spam")
	warning._physics_process(3)
	check(warning.is_queued_for_deletion(), "Area expires")
	boss._area_timer = 0
	boss._area_choice_timer = 0
	boss.blackboard.has_last_seen = false
	check(boss.ai_area_attack() == DecisionNode.Status.FAILURE, "No memory cannot target hidden player")
	print("MUGG COVER/AREA: ",checks," checks; ",failures," failures")
	get_tree().quit(0 if failures == 0 else 1)
