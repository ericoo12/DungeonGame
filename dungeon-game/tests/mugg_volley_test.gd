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
func balls() -> Array[MuggBall]:
	var result: Array[MuggBall] = []
	for child in get_children():
		if child is MuggBall and not child.is_queued_for_deletion():
			result.append(child)
	return result
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
	target.position = Vector2(200,0)
	add_child(target)
	boss.player = target
	await frames()
	boss.navigator.rebuild()
	boss._update_perception(0.1)
	boss.blackboard.distance = 80
	var near := boss.homing_selection_weight()
	boss.blackboard.distance = 180
	var middle := boss.homing_selection_weight()
	boss.blackboard.distance = 280
	var far := boss.homing_selection_weight()
	check(near < middle and middle < far, "Homing weight scales with distance")
	boss.blackboard.distance = 500
	check(boss.homing_selection_weight() == far, "Distance weighting clamps at far setting")
	boss._homing_timer = 1
	check(boss.homing_selection_weight() == 0, "Homing cooldown excludes it from selection")
	boss._homing_timer = 0
	boss._update_perception(0.1)
	check(boss.ai_basic_shot("cluster_shot") == DecisionNode.Status.RUNNING, "Cluster begins committed windup")
	boss._advance_action(boss.cluster_windup - 0.01)
	check(balls().is_empty(), "Cluster does not fire before windup")
	boss._advance_action(0.02)
	var volley := balls()
	check(volley.size() == boss.cluster_count, "Cluster fires configured count")
	var angles := {}
	var speeds := {}
	for ball in volley:
		ball.set_physics_process(false)
		check(absf(rad_to_deg(ball.velocity.angle())) <= boss.cluster_cone_degrees / 2, "Pellet stays within cone")
		angles[ball.velocity.angle()] = true
		speeds[ball.speed] = true
	check(angles.size() == volley.size() and speeds.size() > 1, "Cluster angles and speeds vary")
	check(volley[0].ball_radius < 8.1, "Cluster balls smaller than basic shot")
	boss._advance_action(2)
	check(balls().size() == boss.cluster_count, "Cluster fires only once")
	boss._shot_cooldown = 0
	boss.ai_basic_shot("homing_shot")
	check(boss._active_windup == boss.homing_windup, "Homing uses longer warning")
	boss.stun()
	boss._advance_action(2)
	check(balls().size() == boss.cluster_count, "Stun cancels pending homing shot")
	boss._shot_cooldown = 0
	boss.ai_basic_shot("homing_shot")
	boss._advance_action(boss.homing_windup + 0.01)
	var homing := balls()[-1]
	homing.set_physics_process(false)
	check(homing.homing and homing.ball_color == boss.homing_color, "Homing projectile has distinct configured color")
	check(homing.ball_color != volley[0].ball_color, "Cluster and homing colors differ")
	homing.position = Vector2.ZERO
	homing.velocity = Vector2.RIGHT * homing.speed
	target.position = Vector2(150,80)
	homing.age = homing.tracking_delay
	var before := homing.velocity.angle()
	homing._physics_process(0.1)
	var turned := absf(angle_difference(before,homing.velocity.angle()))
	check(turned > 0 and turned <= deg_to_rad(homing.turn_rate_degrees) * 0.1 + 0.001, "Homing turn rate is bounded")
	homing.age = homing.tracking_delay + homing.tracking_duration
	before = homing.velocity.angle()
	homing._physics_process(0.1)
	check(is_equal_approx(before, homing.velocity.angle()), "Tracking ends after limited duration")
	homing.age = homing.tracking_delay
	homing.position = Vector2.ZERO
	homing.velocity = Vector2.RIGHT * homing.speed
	target.position = Vector2(-50,0)
	homing._physics_process(0.1)
	check(homing.tracking_lost, "Overshoot disables tracking instead of circling back")
	homing.tracking_lost = false
	homing.position = Vector2.ZERO
	homing.velocity = Vector2.RIGHT * homing.speed
	target.position = Vector2(150,0)
	var blue = load("res://scenes/rooms/obstacles/BlueBlock.tscn").instantiate()
	blue.position = Vector2(75,0)
	room.add_child(blue)
	await frames()
	homing._physics_process(0.01)
	check(homing.tracking_lost, "Blue cover breaks homing lock")
	var green = load("res://scenes/rooms/obstacles/GreenBlock.tscn").instantiate()
	green.position = Vector2(-100,80)
	room.add_child(green)
	var passing := MuggBall.new()
	passing.process_mode = Node.PROCESS_MODE_PAUSABLE
	passing.position = Vector2(-150,80)
	passing.speed = 145
	add_child(passing)
	passing.launch(Vector2.RIGHT)
	await frames(40)
	check(is_instance_valid(passing) and passing.position.x > -80, "Actual projectile passes over green block")
	var blocked := MuggBall.new()
	blocked.position = Vector2(30,0)
	blocked.speed = 145
	add_child(blocked)
	blocked.launch(Vector2.RIGHT)
	await frames(30)
	check(not is_instance_valid(blocked), "Blue block destroys actual projectile")
	var age := passing.age
	get_tree().paused = true
	await get_tree().create_timer(0.15,true).timeout
	check(passing.age == age, "Pause freezes projectile movement and lifetime")
	get_tree().paused = false
	passing._physics_process(10)
	check(passing.is_queued_for_deletion(), "Projectile expires")
	print("MUGG VOLLEY: ",checks," checks; ",failures," failures")
	get_tree().quit(0 if failures == 0 else 1)
