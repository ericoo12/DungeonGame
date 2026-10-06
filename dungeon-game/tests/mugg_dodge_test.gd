extends Node
var checks := 0
var failures := 0
var boss: DoktorMugg
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func frames(count: int = 2) -> void:
	for i in count:
		await get_tree().physics_frame
func shot_at(position: Vector2, direction: Vector2 = Vector2.RIGHT) -> Projectile:
	var shot: Projectile = load("res://scenes/player/Projectile.tscn").instantiate()
	shot.position = position
	shot.lifetime = 4
	add_child(shot)
	shot.set_physics_process(false)
	shot.velocity = direction * 120
	shot.add_to_group("projectiles")
	return shot
func reset_boss() -> void:
	boss.cancel_action()
	boss._dodge_timer = 0
	boss._offense_timer = 0
	boss._shot_cooldown = 0
	boss.position = Vector2.ZERO
	boss.dodge_chance = 1
	boss.dodge_left_weight = 1
	boss.dodge_right_weight = 1
	boss.dodge_away_weight = 0.5
	boss.dodge_diagonal_weight = 0.75
	boss._considered_projectiles.clear()
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var room: RoomController = load("res://scenes/rooms/LargeBossRoom.tscn").instantiate()
	add_child(room)
	boss = load("res://scenes/enemies/bosses/DoktorMugg.tscn").instantiate()
	boss.process_mode = Node.PROCESS_MODE_PAUSABLE
	boss.random_seed = 123
	boss.running_shot_weight = 0
	boss.cluster_weight = 0
	boss.homing_near_weight = 0
	boss.homing_far_weight = 0
	boss.spawn_grace_period = 0
	add_child(boss)
	boss.set_physics_process(false)
	boss.set_arena(room)
	var player := Node2D.new()
	player.position = Vector2(150,0)
	add_child(player)
	boss.player = player
	await frames()
	boss.navigator.rebuild()
	var shot := shot_at(Vector2(-60,0))
	reset_boss()
	boss.dodge_chance = 0
	check(boss.ai_dodge() == DecisionNode.Status.FAILURE, "0% never dodges")
	boss.dodge_chance = 1
	check(boss.ai_dodge() == DecisionNode.Status.FAILURE, "Same projectile is not rerolled")
	reset_boss()
	shot.velocity = Vector2.LEFT * 120
	check(boss.ai_dodge() == DecisionNode.Status.FAILURE, "Receding projectile ignored")
	shot.velocity = Vector2.RIGHT * 120
	shot.position.y = 80
	check(boss.ai_dodge() == DecisionNode.Status.FAILURE, "Non-collision course ignored")
	shot.position.y = 0
	boss.dodge_left_weight = 0
	boss.dodge_right_weight = 0
	boss.dodge_diagonal_weight = 0
	boss.dodge_away_weight = 0
	check(boss.ai_dodge() == DecisionNode.Status.FAILURE, "All disabled directions safely fall through")
	reset_boss()
	boss.dodge_right_weight = 0
	boss.dodge_away_weight = 0
	boss.dodge_diagonal_weight = 0
	check(boss.ai_dodge() == DecisionNode.Status.RUNNING, "100% starts eligible dodge")
	check(boss._dodge_direction == Vector2.RIGHT.orthogonal(), "Only enabled direction selected")
	check(boss.action_state == "dodge" and boss.state_machine.is_committed(), "Dodge is a committed action")
	boss._physics_process(0.1)
	check(boss.velocity.length() > boss.move_speed, "Dodge moves faster than walking")
	var hp := boss.health
	boss.take_damage(1)
	check(boss.health == hp - 1 and boss.action_state == "dodge", "Dodge has no free invulnerability and damage preserves commitment")
	boss._physics_process(0.13)
	check(boss.state_machine.state == MuggStateMachine.State.DODGE_RECOVERY, "Dodge enters recovery")
	boss._physics_process(0.05)
	check(boss.velocity == Vector2.ZERO, "Recovery stops dash movement")
	boss._advance_action(1)
	check(boss.action_state == "" and boss._dodge_direction == Vector2.ZERO, "Completed dodge cleans up")
	check(boss.ai_dodge() == DecisionNode.Status.FAILURE, "Cooldown prevents dodge spam")
	reset_boss()
	boss.ai_dodge()
	boss.stun()
	check(boss.action_state == "damage" and boss._dodge_direction == Vector2.ZERO, "Stun cancels dodge")
	reset_boss()
	boss._update_perception(0.1)
	boss.ai_basic_shot()
	check(boss.ai_dodge() == DecisionNode.Status.FAILURE, "Dodge cannot cancel attack windup")
	reset_boss()
	boss.ai_dodge()
	boss.set_physics_process(true)
	get_tree().paused = true
	await get_tree().create_timer(0.12, true).timeout
	check(boss.action_elapsed == 0, "Pause freezes dodge")
	get_tree().paused = false
	boss.set_physics_process(false)
	reset_boss()
	boss.position = Vector2(375,0)
	shot.position = Vector2(315,0)
	boss.dodge_left_weight = 0
	boss.dodge_right_weight = 0
	boss.dodge_diagonal_weight = 0
	boss.dodge_away_weight = 1
	check(boss.ai_dodge() == DecisionNode.Status.FAILURE, "Reject dash through outer wall")
	reset_boss()
	shot.position = Vector2(-60,0)
	var directions := {}
	for i in 80:
		reset_boss()
		boss.ai_dodge()
		directions[boss._dodge_direction] = true
	check(directions.size() >= 4, "Seeded weighted selection produces varied directions")
	reset_boss()
	boss.ai_dodge()
	var start := boss.position
	boss.set_physics_process(true)
	await frames(20)
	boss.set_physics_process(false)
	var traveled := boss.position.distance_to(start)
	check(traveled > 55 and traveled <= boss.dodge_speed * boss.dodge_duration + 2, "Real physics dodge travels configured distance without duplicate movement")
	check(boss.velocity == Vector2.ZERO, "Real-frame dodge recovery is stationary")
	reset_boss()
	boss._update_perception(0.1)
	boss.basic_shot_weight = 1
	boss.tactical_move_weight = 0
	check(boss.ai_choose_offense() == DecisionNode.Status.RUNNING and boss.action_state == "basic_shot", "Shot-only weighting selects shot")
	reset_boss()
	boss.basic_shot_weight = 0
	boss.tactical_move_weight = 1
	boss._reposition_timer = 0
	boss._movement_retry = 0
	boss.ai_choose_offense()
	check(boss.action_state == "" and not boss.navigator.path.is_empty(), "Movement-only weighting chooses route")
	check(boss.ai_choose_offense() == DecisionNode.Status.FAILURE, "Tactics do not reroll every tick")
	reset_boss()
	boss.basic_shot_weight = 0
	boss.tactical_move_weight = 0
	check(boss.ai_choose_offense() == DecisionNode.Status.FAILURE, "Zero tactic weights safely fall through")
	boss.ai_dodge()
	boss.take_damage(10000)
	check(boss.is_dying and boss._dodge_direction == Vector2.ZERO, "Death cancels dodge")
	print("MUGG DODGE: ", checks, " checks; ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
