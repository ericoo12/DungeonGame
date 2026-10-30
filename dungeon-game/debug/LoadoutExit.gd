## TestRoom exit: walk into this toilet to start a real run (stage 1) with everything
## you picked up in the item room - passive items, active item (and its charges) and
## ducks. For recording the trailer with hand-picked item combos.
## GameState.start_loadout carries the items over; Dungeon applies them when it starts.
extends Area2D

const DOOR_PATH := "res://assets/sprites/objects//toilet.png"  # same art as the stage door
const GAME_SCENE := "res://dungeon/Dungeon.tscn"

var _used := false


func _ready() -> void:
	collision_mask = 2   # player body
	monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 20)
	shape.shape = rect
	add_child(shape)

	var art := Node2D.new()
	art.scale = Vector2(0.05, 0.05)
	add_child(art)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = AnimSheetLoader.build_single_animation_indexed(DOOR_PATH, [2, 3], 4, 4.0, true, "open")
	sprite.play("open")
	art.add_child(sprite)

	var label := Label.new()
	label.text = "START RUN\n(stage 1, keeps your items)"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 6)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.size = Vector2(90, 0)
	label.position = Vector2(-45, 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player == null or _used:
		return
	_used = true
	var items: Array = player.items.duplicate()
	var active := player.active_item
	var charges := player.active_item_charges
	var ducks := player.ducks
	GameState.reset()  # fresh run: stage 1, new seed
	GameState.start_loadout = {"items": items, "active": active, "charges": charges, "ducks": ducks}
	get_tree().call_deferred("change_scene_to_file", GAME_SCENE)
