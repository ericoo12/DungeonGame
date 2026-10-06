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
	var player: Player = load("res://scenes/player/Player.tscn").instantiate()
	player.position = Vector2(180,0)
	add_child(player)
	player.set_physics_process(false)
	var boss: DoktorMugg = load("res://scenes/enemies/bosses/DoktorMugg.tscn").instantiate()
	add_child(boss)
	boss.set_physics_process(false)
	boss.set_arena(room)
	boss.player = player
	await get_tree().physics_frame
	await get_tree().physics_frame
	boss._update_perception(0.1)
	check(boss.health_aggression() == 0 and boss.health_defense() == 0, "Full health preserves neutral tactics")
	check(boss.effective_preferred_distance() == boss.preferred_distance, "Neutral spacing unchanged")
	player.current_hearts = 1
	boss._update_perception(0.1)
	var aggression := boss.health_aggression()
	check(aggression > 0, "Visible player at one heart triggers aggression")
	check(boss.effective_attack_cooldown_scale() < 1, "Low player health speeds attack cadence")
	check(boss.effective_preferred_distance() < boss.preferred_distance, "Low player health closes distance")
	boss.cooldown_variation = 0
	boss.ai_basic_shot()
	check(boss._shot_cooldown < boss.attack_cooldown, "Actual attack uses health-scaled cooldown")
	boss.cancel_action()
	boss.health = boss.max_health * 0.2
	check(boss.health_defense() > 0.5, "Low boss health triggers defense")
	check(boss.health_aggression() < aggression, "Both low favors self-preservation")
	check(boss.effective_preferred_distance() > boss.preferred_distance, "Wounded boss seeks extra spacing")
	check(boss.effective_dodge_chance() > boss.dodge_chance, "Wounded boss more likely to dodge")
	check(boss.effective_defense_cooldown_scale() < 1, "Wounded boss can dodge and seek cover more often")
	boss.health = boss.max_health
	player.current_hearts = player.max_hearts
	boss._update_perception(0.1)
	check(boss.health_aggression() == 0 and boss.health_defense() == 0, "Healing restores baseline without accumulating modifiers")
	var blue = load("res://scenes/rooms/obstacles/BlueBlock.tscn").instantiate()
	blue.position = Vector2(90,0)
	room.add_child(blue)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.current_hearts = 1
	boss._update_perception(0.1)
	check(not boss.blackboard.player_visible and boss.health_aggression() == 0, "Hidden health changes do not grant information")
	boss.health_tactics_enabled = false
	boss.health = 1
	boss._observed_player_health_ratio = 0.1
	check(boss.health_defense() == 0 and boss.health_aggression() == 0, "Inspector switch disables health tactics")
	check(boss.max_health == 100 and boss.projectile_damage == 1, "Health and damage stats unchanged")
	print("MUGG HEALTH: ",checks," checks; ",failures," failures")
	get_tree().quit(0 if failures == 0 else 1)
