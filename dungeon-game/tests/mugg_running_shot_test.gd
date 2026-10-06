extends Node
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var room: RoomController = load("res://scenes/rooms/LargeBossRoom.tscn").instantiate()
	add_child(room)
	var boss: DoktorMugg = load("res://scenes/enemies/bosses/DoktorMugg.tscn").instantiate()
	boss.spawn_grace_period = 0
	boss.random_seed = 123
	boss.basic_shot_weight = 0
	boss.cluster_weight = 0
	boss.homing_near_weight = 0
	boss.homing_far_weight = 0
	boss.tactical_move_weight = 0
	add_child(boss)
	boss.set_physics_process(false)
	boss.set_arena(room)
	var target := Node2D.new()
	target.position = Vector2(190,0)
	add_child(target)
	boss.player = target
	await get_tree().physics_frame
	await get_tree().physics_frame
	boss.navigator.rebuild()
	boss._update_perception(0.1)
	check(boss.ai_choose_offense() == DecisionNode.Status.RUNNING and boss.action_state == "running_shot", "Weighted selector can choose running shot")
	boss._physics_process(0.06)
	check(boss.velocity.length() > boss.move_speed * 0.99, "Full movement speed during short windup")
	check(boss.blackboard.shots_fired == 0, "No premature shot")
	boss._physics_process(0.07)
	check(boss.velocity.length() > boss.move_speed * 0.99, "No stationary plant at release")
	check(boss.blackboard.shots_fired == 1, "Running shot fires once")
	boss._physics_process(0.09)
	check(boss.velocity.length() > boss.move_speed * 0.99 and boss.state_machine.state == MuggStateMachine.State.RECOVERY, "Full movement during recovery")
	boss._advance_action(0.15)
	check(boss.action_state == "", "Short action duration not extended by animation")
	check(boss.blackboard.shots_fired == 1, "Recovery never repeats projectile")
	boss._shot_cooldown = 0
	boss.ai_basic_shot("running_shot")
	boss.stun()
	boss._advance_action(1)
	check(boss.blackboard.shots_fired == 1, "Stun cancels pending running shot")
	check(boss.attack_cooldown < 1 and boss.windup_duration < 0.3, "Faster regular attacks configured")
	check(boss.cluster_windup < 0.4 and boss.homing_windup < 0.5, "Faster special attacks configured")
	check(boss.max_health == 100, "Health unchanged")
	print("MUGG RUNNING SHOT: ",checks," checks; ",failures," failures")
	get_tree().quit(0 if failures == 0 else 1)
