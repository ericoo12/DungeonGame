extends Node
var checks := 0
var failures := 0
var boss: DoktorMugg
var target: Node2D
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func frames(n: int = 2) -> void:
	for i in n:
		await get_tree().physics_frame
func reset() -> void:
	boss.cancel_action()
	boss.navigator.stop()
	boss.state_machine.transition(MuggStateMachine.State.IDLE, true)
	boss.position = Vector2.ZERO
	boss.health = boss.max_health
	boss._offense_timer = 0
	boss._shot_cooldown = 0
	boss._dodge_timer = 0
	boss._cover_timer = 0
	boss._area_timer = 0
	boss._area_choice_timer = 0
	boss._reposition_timer = 0
	boss._movement_retry = 0
	boss._considered_projectiles.clear()
	boss._recent_damage = 0
	boss._blocked_duration = 0
	target.position = Vector2(180,0)
	boss._update_perception(0.1)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var room: RoomController = load("res://scenes/rooms/LargeBossRoom.tscn").instantiate()
	add_child(room)
	boss = load("res://scenes/enemies/bosses/DoktorMugg.tscn").instantiate()
	boss.random_seed = 17
	boss.spawn_grace_period = 0
	add_child(boss)
	boss.set_physics_process(false)
	boss.set_arena(room)
	target = Node2D.new()
	add_child(target)
	boss.player = target
	await frames()
	boss.navigator.rebuild()
	reset()
	check(boss.attack_range == 350 and boss.projectile_speed == 240, "Existing scene overrides survive inherited settings")
	boss.basic_shot_weight = 0
	boss.cluster_weight = 0
	boss.homing_near_weight = 0
	boss.homing_far_weight = 0
	boss.running_shot_weight = 1
	boss.tactical_move_weight = 0
	boss.behavior_tree.tick()
	check(boss.blackboard.situation == "COMBAT" and boss.action_state == "running_shot", "Combat context selects its enabled attack")
	var decision := boss.blackboard.chosen_response
	boss.behavior_tree.tick()
	check(boss.action_elapsed == 0 and boss.blackboard.chosen_response == decision, "FSM gate prevents action restart")
	boss.stun(0.3)
	boss.behavior_tree.tick()
	check(boss.state_machine.state == MuggStateMachine.State.STUNNED, "FSM gate preserves stun")
	reset()
	boss._shot_cooldown = 10
	boss.behavior_tree.tick()
	check(boss.blackboard.situation == "COMBAT" and boss.state_machine.state == MuggStateMachine.State.KITE, "Cooldown keeps combat movement without pretending to search")
	reset()
	target.position = Vector2(40,0)
	boss._update_perception(0.1)
	boss.close_running_shot_weight = 1
	boss.close_dodge_weight = 0
	boss.close_area_weight = 0
	boss.close_retreat_weight = 0
	boss.close_cover_weight = 0
	boss.behavior_tree.tick()
	check(boss.blackboard.situation == "TOO_CLOSE" and boss.action_state == "running_shot", "Close context has its own weights")
	reset()
	target.position = Vector2(40,0)
	boss._update_perception(0.1)
	boss.close_running_shot_weight = 0
	boss.close_dodge_weight = 1
	boss.dodge_chance = 1
	boss.behavior_tree.tick()
	check(boss.action_state == "dodge", "Close context can dash away without a projectile")
	reset()
	boss.blackboard.player_visible = false
	boss.blackboard.shot_clear = false
	boss._blocked_duration = 1
	boss.blocked_area_weight = 1
	boss.blocked_flank_weight = 0
	boss.blocked_investigate_weight = 0
	boss.area_anti_cover_chance = 1
	boss.behavior_tree.tick()
	check(boss.blackboard.situation == "BLOCKED" and boss.action_state == "area_attack", "Blocked context can flush remembered cover")
	reset()
	boss.blackboard.forget()
	boss.behavior_tree.tick()
	check(boss.state_machine.state == MuggStateMachine.State.IDLE, "No memory idles")
	reset()
	target.position = Vector2(370,0)
	boss._update_perception(0.1)
	boss.behavior_tree.tick()
	check(boss.blackboard.situation == "SEARCH", "Out of range uses approach/search context")
	reset()
	var projectile: Projectile = load("res://scenes/player/Projectile.tscn").instantiate()
	projectile.position = Vector2(-60,0)
	projectile.lifetime = 4
	add_child(projectile)
	projectile.set_physics_process(false)
	projectile.velocity = Vector2.RIGHT * 120
	projectile.add_to_group("projectiles")
	boss.danger_dodge_weight = 1
	boss.danger_cover_weight = 0
	boss.danger_running_shot_weight = 0
	boss.danger_retreat_weight = 0
	boss.behavior_tree.tick()
	check(boss.blackboard.situation == "DANGER" and boss.action_state == "dodge", "Danger outranks normal offense")
	reset()
	boss.danger_dodge_weight = 0
	boss.danger_running_shot_weight = 1
	boss.behavior_tree.tick()
	check(boss.action_state == "running_shot", "Danger response is weighted, not always dodge")
	projectile.queue_free()
	await frames()
	reset()
	# Failed selected response is removed before trying another eligible response.
	boss.blackboard.player_visible = false
	boss.blackboard.shot_clear = false
	boss._blocked_duration = 1
	boss.blocked_area_weight = 100000
	boss.area_anti_cover_chance = 0
	boss.blocked_investigate_weight = 1
	boss.behavior_tree.tick()
	check(boss.action_state != "area_attack" and not boss.navigator.path.is_empty(), "Failed area roll falls back to investigation")
	check(boss._area_choice_timer > 0, "Failed area roll cannot immediately repeat")
	reset()
	boss.navigator.set_path(PackedVector2Array([Vector2(0,60)]))
	boss.state_machine.transition(MuggStateMachine.State.REPOSITION)
	check(not boss.state_machine.can_choose_tactic(boss), "Movement commitment remains guarded without danger")
	reset()
	boss.running_shot_weight = 0
	boss.combat_cover_weight = 0
	check(boss.ai_choose_offense() == DecisionNode.Status.FAILURE, "All-zero offensive weights safely fail")
	var zeroes: Array = []
	boss.tactics._offer(zeroes,"disabled",0,true,func(): return DecisionNode.Status.SUCCESS)
	boss.tactics._offer(zeroes,"unavailable",10,false,func(): return DecisionNode.Status.SUCCESS)
	check(zeroes.is_empty(), "Zero/unavailable choices never enter lottery")
	var choices := [{"weight":1.0},{"weight":3.0}]
	var first := 0
	for i in 1000:
		if boss.tactics._weighted_index(choices) == 0:
			first += 1
	check(first > 190 and first < 310, "Seeded 1:3 sampling follows relative weights")
	var neutral: float = boss.tactics._defense_weight()
	boss.health = 15
	check(boss.tactics._defense_weight() > neutral, "Health modifies context response weights")
	boss.is_dying = true
	check(not boss.state_machine.can_choose_tactic(boss), "Death blocks new decisions")
	print("MUGG SITUATIONS: ",checks," checks; ",failures," failures")
	get_tree().quit(0 if failures == 0 else 1)
