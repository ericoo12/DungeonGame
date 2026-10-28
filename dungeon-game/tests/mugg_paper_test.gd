extends Node2D
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var player: Player = load("res://player/Player.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.position = Vector2(500, 500)
	player.take_damage(0.5)
	check(player.current_hearts == 2.5, "Half-heart damage is preserved")
	player.take_damage(0.5)
	check(player.current_hearts == 2.5, "Invulnerability prevents stacked trail hits")
	player.invulnerable = false
	player.take_damage(1.0)
	check(player.current_hearts == 1.5, "Basic damage removes one full heart")
	var ui := HeartsDisplay.new()
	add_child(ui)
	ui._on_health_changed(1.5, 3)
	check(ui.current_hearts == 1.5, "HUD retains half hearts")
	var trail := MuggPaperTrail.new()
	add_child(trail)
	trail.add_segment(Vector2(490,500), Vector2(510,500))
	player.invulnerable = false
	trail._physics_process(0.01)
	check(player.current_hearts == 1.0, "Stepping on paper costs half a heart")
	trail._physics_process(1.0)
	check(trail.segments.is_empty(), "Paper expires after one second")
	var block: ArenaObstacle = load("res://enemies/doktor_mugg/arena_obstacles/ArenaObstacle.tscn").instantiate()
	block.blocks_projectiles = false
	block.blocks_sight = false
	block.position = Vector2(70,0)
	add_child(block)
	await frames(3)
	var homing := MuggBall.new()
	homing.homing = true
	homing.speed = 600
	add_child(homing)
	homing.launch(Vector2.RIGHT)
	await frames(12)
	check(is_instance_valid(homing) and homing.position.x > 90, "Homing paper rolls over green block")
	homing.queue_free()
	var straight := MuggBall.new()
	straight.speed = 600
	add_child(straight)
	straight.launch(Vector2.RIGHT)
	await frames(12)
	check(is_instance_valid(straight) and straight.position.x > 90, "Ordinary paper flies over green")
	straight.queue_free()
	block.blocks_projectiles = true
	await frames(3)
	var blue_test := MuggBall.new()
	blue_test.speed = 600
	add_child(blue_test)
	blue_test.launch(Vector2.RIGHT)
	await frames(12)
	check(not is_instance_valid(blue_test), "Blue cover stops ordinary paper")
	var settings := MuggSettings.new()
	check(settings.projectile_damage == 0.5 and settings.running_shot_damage == 0.5 and settings.cluster_damage == 0.5, "Attack damage defaults match requested hearts")
	settings.free()
	await frames(70)
	check(get_tree().get_nodes_in_group("mugg_paper_trails").is_empty(), "Trail cleans up after projectile removal")
	print("Paper tests: %d checks, %d failures" % [checks, failures])
	get_tree().quit(failures)
