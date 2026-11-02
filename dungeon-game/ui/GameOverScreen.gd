## Game over screen: shown when the player dies (Player._die). Freezes the game, fades in
## over it and shows how far the run got - stage, time, ducks and the items collected -
## with Try Again (a new run) and Main Menu. Keyboard-driven (arrows + Enter/Space).
## Built in code and styled via UIStyle, like MainMenu.
extends CanvasLayer
class_name GameOverScreen

const GAME_SCENE := "res://dungeon/Dungeon.tscn"
const MENU_SCENE := "res://ui/MainMenu.tscn"
const FADE_TIME := 0.6
const TITLE_TEXT := "FLUSHED"
const SUBTITLE_TEXT := "Your run went down the drain."
const ICON_SIZE := 34.0
const MAX_ICONS := 24

## Filled in by show_for() before the run is reset.
var stage: int = 1
var run_seconds: float = 0.0
var ducks: int = 0
var items: Array = []        # ItemBase (passives + the active item)
var best_stage: int = 0

var _root: Control
var _shade: ColorRect
var _buttons: Array[Button] = []
var _leaving := false


## Freezes the game and shows the screen for `player`'s run.
static func show_for(player: Player) -> void:
	var tree := player.get_tree()
	var screen := GameOverScreen.new()
	screen.stage = GameState.current_stage
	screen.run_seconds = GameState.run_seconds()
	screen.ducks = player.ducks
	screen.items = []  # untyped copy: holds the active item too
	screen.items.append_array(player.items)
	if player.active_item:
		screen.items.append(player.active_item)
	screen.best_stage = Discovery.best_stage()
	tree.root.add_child(screen)
	tree.paused = true


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_over")
	_build()
	# Fade in: the dark-red shade first, then the panel.
	_shade.color.a = 0.0
	_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_shade, "color:a", 0.82, FADE_TIME)
	tween.tween_property(_root, "modulate:a", 1.0, 0.35)
	tween.tween_callback(func(): _buttons[0].grab_focus())


func _build() -> void:
	_shade = ColorRect.new()
	_shade.color = Color(0.13, 0.02, 0.02, 0.82)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)

	_root = CenterContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	_root.add_child(column)

	var title := UIStyle.label(TITLE_TEXT, 84, UIStyle.COL_BAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 12)
	column.add_child(title)
	var subtitle := UIStyle.label(SUBTITLE_TEXT, 22, UIStyle.COL_MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	# Run summary panel.
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.COL_PANEL, UIStyle.COL_PANEL_BORDER, 3, 18))
	column.add_child(panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	panel.add_child(info)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 40)
	stats.add_theme_constant_override("v_separation", 4)
	info.add_child(stats)
	_stat_row(stats, "Reached", "Stage %d" % stage)
	_stat_row(stats, "Time", _time_text(run_seconds))
	_stat_row(stats, "Ducks", str(ducks))
	_stat_row(stats, "Best", ("Stage %d cleared" % best_stage) if best_stage > 0 else "-")

	info.add_child(UIStyle.divider())
	var items_title := UIStyle.label("ITEMS (%d)" % items.size(), 15, UIStyle.COL_MUTED)
	info.add_child(items_title)
	if items.is_empty():
		info.add_child(UIStyle.label("None - went in empty-handed.", 16, UIStyle.COL_MUTED))
	else:
		var grid := GridContainer.new()
		grid.columns = 12
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		info.add_child(grid)
		for i in mini(items.size(), MAX_ICONS):
			var item: ItemBase = items[i]
			var icon := TextureRect.new()
			icon.texture = item.icon
			icon.custom_minimum_size = Vector2.ONE * ICON_SIZE
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.tooltip_text = item.item_name
			grid.add_child(icon)
		if items.size() > MAX_ICONS:
			info.add_child(UIStyle.label("+%d more" % (items.size() - MAX_ICONS), 14, UIStyle.COL_MUTED))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_add_button(buttons, "Try Again", _on_try_again)
	_add_button(buttons, "Main Menu", _on_main_menu)


func _stat_row(grid: GridContainer, name: String, value: String) -> void:
	grid.add_child(UIStyle.label(name, 18, UIStyle.COL_MUTED))
	grid.add_child(UIStyle.label(value, 18, UIStyle.COL_TEXT))


static func _time_text(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 52)
	UIStyle.style_button(button, 22)
	button.pressed.connect(callback)
	button.mouse_entered.connect(func(): if not button.disabled: button.grab_focus())
	parent.add_child(button)
	_buttons.append(button)


func _on_try_again() -> void:
	_leave(func():
		GameState.reset()
		var scene := get_tree().current_scene
		# Died in a test room: replay that room, otherwise a fresh dungeon run.
		if scene and scene.scene_file_path != "" and scene.scene_file_path != GAME_SCENE:
			get_tree().reload_current_scene()
		else:
			get_tree().change_scene_to_file(GAME_SCENE))


func _on_main_menu() -> void:
	_leave(func():
		GameState.reset()
		get_tree().change_scene_to_file(MENU_SCENE))


func _leave(then: Callable) -> void:
	if _leaving:
		return
	_leaving = true
	for b in _buttons:
		b.disabled = true
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.2)
	tween.tween_property(_shade, "color", Color.BLACK, 0.25)
	tween.tween_callback(func():
		get_tree().paused = false
		then.call()
		queue_free())
