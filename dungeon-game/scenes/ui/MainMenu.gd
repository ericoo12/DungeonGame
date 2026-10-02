## Title screen. Built in code (like InventoryOverlay) and styled via UIStyle.
## Backdrop = the sewer room floor, darkened with a vignette; animated title;
## keyboard + mouse menu; controls panel read from the InputMap; fades in/out.
extends Control
class_name MainMenu

const GAME_SCENE := "res://scenes/dungeon/Dungeon.tscn"
const BACKDROP := preload("res://assets/sprites/tiles/sewer.png")
const BACKDROP_REGION := Rect2(10, 0, 202, 112)  # same crop RoomBase uses for its floor quarters

const TITLE_TEXT := "POOPINATOR"
const SUBTITLE_TEXT := "Return of the Shit"
const CREDITS_TEXT := "Eric Åhlén & Albin Will"
const FADE_TIME := 0.35

var _buttons: Array[Button] = []
var _title: Label
var _fade: ColorRect
var _time := 0.0
var _leaving := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_buttons[0].grab_focus()
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, FADE_TIME)


func _process(delta: float) -> void:
	# Gentle wobble + pulse. Rotation/scale (not position) so the containers don't fight it.
	_time += delta
	_title.pivot_offset = _title.size / 2.0
	_title.rotation = deg_to_rad(sin(_time * 1.6) * 1.5)
	_title.scale = Vector2.ONE * (1.0 + sin(_time * 2.4) * 0.025)


# --- Actions -------------------------------------------------------------------

func _on_new_game() -> void:
	if _leaving:
		return
	_leaving = true
	_set_buttons_enabled(false)
	GameState.reset()  # fresh run: stage 1, no picked-up items
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	tween.tween_callback(func(): get_tree().change_scene_to_file(GAME_SCENE))


func _on_quit() -> void:
	if _leaving:
		return
	_leaving = true
	_set_buttons_enabled(false)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	tween.tween_callback(func(): get_tree().quit())


func _set_buttons_enabled(enabled: bool) -> void:
	for b in _buttons:
		b.disabled = not enabled


# --- UI construction -------------------------------------------------------------

func _build_ui() -> void:
	_build_backdrop()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 26)
	center.add_child(column)

	# Title block
	var title_block := VBoxContainer.new()
	title_block.add_theme_constant_override("separation", 0)
	column.add_child(title_block)
	_title = UIStyle.label(TITLE_TEXT, 76, UIStyle.COL_TITLE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_constant_override("outline_size", 12)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 6)
	title_block.add_child(_title)
	var subtitle := UIStyle.label(SUBTITLE_TEXT, 24, UIStyle.COL_ACTIVE)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_block.add_child(subtitle)

	# Menu panel
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.COL_PANEL, UIStyle.COL_PANEL_BORDER, 3, 18))
	column.add_child(panel)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	panel.add_child(menu)
	_add_button(menu, "New Game", _on_new_game)
	_add_button(menu, "Quit", _on_quit)

	# Controls
	var controls := PanelContainer.new()
	controls.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	controls.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.COL_INSET, UIStyle.COL_SLOT_BORDER, 1, 12))
	column.add_child(controls)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	controls.add_child(grid)
	_add_control_row(grid, "Move", _keys_text(["move_up", "move_left", "move_down", "move_right"]))
	_add_control_row(grid, "Shoot", _keys_text(["shoot_up", "shoot_left", "shoot_down", "shoot_right"]))
	_add_control_row(grid, "Use item", UIStyle.action_key_text("use_active_item"))
	_add_control_row(grid, "Inventory", UIStyle.action_key_text("toggle_items"))

	# Credits, bottom-right
	var credits := UIStyle.label(CREDITS_TEXT, 13, UIStyle.COL_MUTED)
	credits.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	credits.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	credits.grow_vertical = Control.GROW_DIRECTION_BEGIN
	credits.offset_right = -14
	credits.offset_bottom = -10
	add_child(credits)

	# Fade overlay on top of everything
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


## Sewer floor as 4 mirrored quarters (exactly how RoomBase lays it out), stretched to
## the screen, then darkened + vignetted so the menu reads on top.
func _build_backdrop() -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = BACKDROP
	atlas.region = BACKDROP_REGION

	var quarters := GridContainer.new()
	quarters.columns = 2
	quarters.add_theme_constant_override("h_separation", 0)
	quarters.add_theme_constant_override("v_separation", 0)
	quarters.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quarters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(quarters)
	for flips in [[false, false], [true, false], [false, true], [true, true]]:
		var quarter := TextureRect.new()
		quarter.texture = atlas
		quarter.flip_h = flips[0]
		quarter.flip_v = flips[1]
		quarter.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		quarter.stretch_mode = TextureRect.STRETCH_SCALE
		quarter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		quarter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quarter.size_flags_vertical = Control.SIZE_EXPAND_FILL
		quarter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quarters.add_child(quarter)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.0))
	gradient.set_color(1, Color(0, 0, 0, 0.85))
	var vignette_tex := GradientTexture2D.new()
	vignette_tex.gradient = gradient
	vignette_tex.fill = GradientTexture2D.FILL_RADIAL
	vignette_tex.fill_from = Vector2(0.5, 0.5)
	vignette_tex.fill_to = Vector2(1.05, 1.05)
	var vignette := TextureRect.new()
	vignette.texture = vignette_tex
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)


func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 52)
	UIStyle.style_button(button, 22)
	button.pressed.connect(callback)
	# Mouse and keyboard share one highlight: hovering moves focus.
	button.mouse_entered.connect(_on_button_hovered.bind(button))
	parent.add_child(button)
	_buttons.append(button)


func _on_button_hovered(button: Button) -> void:
	if not button.disabled:
		button.grab_focus()


func _add_control_row(grid: GridContainer, action_name: String, keys: String) -> void:
	grid.add_child(UIStyle.label(action_name, 14, UIStyle.COL_MUTED))
	grid.add_child(UIStyle.label(keys, 14, UIStyle.COL_TEXT))


## "W A S D", or "Arrow keys" when the four actions are bound to the arrows.
func _keys_text(actions: Array) -> String:
	var keys := PackedStringArray()
	for a in actions:
		keys.append(UIStyle.action_key_text(a))
	if Array(keys) == ["Up", "Left", "Down", "Right"]:
		return "Arrow keys"
	return " ".join(keys)
