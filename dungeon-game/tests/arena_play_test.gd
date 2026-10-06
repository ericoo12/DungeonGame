extends Node
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://scenes/test/DoktorMuggArena.tscn").instantiate()
	add_child(arena)
	arena.boss.set_physics_process(false)
	arena.room.get_node("Obstacles").queue_free()
	await frames(10)
	var player: Player = arena.player
	check(arena.room.get_arena_bounds().size == Vector2(864,448), "Four-room area")
	check(not arena.room.has_node("Obstacles"), "No obstacles")
	check(player.is_inside_tree() and player.is_physics_processing(), "Player spawns and processes")
	check(player.camera.is_current(), "Player camera active")
	var screen: Vector2 = player.get_global_transform_with_canvas().origin
	print("PLAYER SCREEN ",screen," VIEWPORT ",get_viewport().get_visible_rect())
	check(get_viewport().get_visible_rect().has_point(screen), "Player visible in viewport")
	for action in ["move_right", "move_down", "move_left", "move_up"]:
		var start := player.position
		Input.action_press(action)
		await frames(30)
		Input.action_release(action)
		check(player.position.distance_to(start) > 35, "Player moves: " + action)
	# Cross both old normal-room boundaries in the enlarged interior.
	player.position = Vector2(-280, 0)
	Input.action_press("move_right")
	await frames(330)
	Input.action_release("move_right")
	check(player.position.x > 250, "No old wall across enlarged interior")
	player.position = Vector2(100, -150)
	Input.action_press("move_down")
	await frames(180)
	Input.action_release("move_down")
	check(player.position.y > 125, "Open vertical interior")
	player.position = Vector2(100, 0)
	Input.action_press("move_right")
	await frames(240)
	Input.action_release("move_right")
	check(player.position.x < 402 and player.position.x > 360, "Outer wall stops player")
	player.position = Vector2(-250,-70)
	await frames(3)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://arena-preview.png")
	print("ARENA PLAY: ",checks," checks; ",failures," failures")
	get_tree().quit(0 if failures == 0 else 1)
