extends Node
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func frames(n: int = 2) -> void:
	for i in n:
		await get_tree().physics_frame
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var room: RoomController = load("res://scenes/rooms/LargeBossRoom.tscn").instantiate()
	add_child(room)
	var boss: DoktorMugg = load("res://scenes/enemies/bosses/DoktorMugg.tscn").instantiate()
	boss.random_seed = 123
	boss.spawn_grace_period = 0
	add_child(boss)
	boss.set_physics_process(false)
	boss.set_arena(room)
	var target := Node2D.new()
	target.position = Vector2(70,0)
	add_child(target)
	boss.player = target
	await frames()
	boss.navigator.rebuild()
	boss._update_perception(0.1)
	var retreat := boss._kite_velocity(1.0/60)
	check(retreat.x < -50, "Kiting retreats from close player")
	target.position = Vector2(boss.preferred_distance,0)
	boss._update_perception(0.1)
	boss._kite_steer_timer = 0
	var strafe := boss._kite_velocity(1.0/60)
	check(absf(strafe.y) > absf(strafe.x), "Kiting circles at preferred range")
	check(is_equal_approx(strafe.length(),boss.move_speed), "Kiting respects configured movement speed")
	boss._shot_cooldown = 0
	boss.ai_basic_shot()
	boss._update_cooldowns(0.05)
	boss._advance_action(0.05)
	check(boss.velocity.length() > 0, "Windup moves before final plant window")
	boss.velocity = Vector2.ZERO
	boss._advance_action(boss._active_windup - boss.kite_plant_window * 0.5 - boss.action_elapsed)
	check(boss.velocity == Vector2.ZERO, "Final release plant remains readable")
	boss._advance_action(boss.kite_plant_window + boss.fire_duration + 0.01)
	check(boss.velocity.length() > 0 and boss.state_machine.state == MuggStateMachine.State.RECOVERY, "Recovery moves without cancelling attack")
	check(boss.blackboard.shots_fired == 1, "Moving attack still fires exactly once")
	boss.cancel_action()
	var health := boss.health
	boss.take_damage(1)
	check(boss.health == health-1 and boss.action_state == "", "Ordinary damage applies without repeated stagger")
	boss.stun(0.3)
	check(boss.action_state == "damage", "Explicit stun still interrupts kiting")
	boss.cancel_action()
	boss.position = Vector2(375,160)
	target.position = Vector2(300,100)
	boss._update_perception(0.1)
	boss._kite_steer_timer = 0
	var escape := boss._kite_velocity(1.0/60)
	check(escape.length() > 0 and boss.navigator.segment_clear(boss.position,boss.position+escape/60), "Corner steering chooses a clear escape")
	boss.blackboard.forget()
	check(boss._kite_velocity(1.0/60) == Vector2.ZERO, "No memory stops pursuit")
	boss.position = Vector2.ZERO
	target.position = Vector2(180,0)
	boss._update_perception(0.1)
	boss._shot_cooldown = 0
	boss._offense_timer = 0
	boss.area_enabled = false
	boss.set_physics_process(true)
	var moving := 0
	var safe := true
	for i in 360:
		await get_tree().physics_frame
		if boss.velocity.length() > 1:
			moving += 1
		safe = safe and boss.navigator.position_clear(boss.position)
	boss.set_physics_process(false)
	check(moving > 240, "Real fight moves on at least two thirds of frames")
	check(boss.blackboard.shots_fired >= 3, "Sustained kiting maintains attack pressure")
	check(safe, "Real fight stays inside safe arena geometry")
	check(boss.max_health == 100, "Boss health unchanged")
	print("MUGG KITING: ",checks," checks; ",failures," failures; moving frames ",moving,"/360")
	get_tree().quit(0 if failures == 0 else 1)
