## Logbook: every item and enemy, and what you've learned about them across runs
## (Discovery). Undiscovered entries are dark silhouettes with "??".
## Items:   name, flavour, what it does, stat changes, times picked up.
## Enemies: name, description, health / contact damage / speed, times killed.
## Opened from the main menu. Built in code and styled with UIStyle (like InventoryOverlay).
## Keyboard only: Tab / Shift+Tab cycles Items -> Enemies -> Close -> Forget, arrow keys
## (or WASD) browse the grid of the current page only, Space / Enter presses, Esc closes.
extends Control
class_name Logbook

signal closed

const ITEM_FOLDER := "res://data/items/"
const ENEMY_FOLDERS := ["res://enemies/regular/", "res://enemies/bosses/"]
const EXTRA_ENEMIES := ["res://enemies/doktor_mugg/DoktorMugg.tscn"]
const SLOT_SIZE := 60
const COLUMNS := 8

var _tab: String = "items"
var _items: Array[ItemBase] = []
var _enemies: Array[Dictionary] = []   # {path, name, desc, icon, health, damage, speed}

var _grid: GridContainer
var _progress: Label
var _tab_buttons: Dictionary = {}
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_tag: Label
var _detail_flavor: Label
var _detail_body: RichTextLabel
var _forget_button: Button
var _forget_armed: bool = false
var _close_button: Button
## Tab order of the header/footer: "items", "enemies", "close", "forget".
const TAB_ORDER := ["items", "enemies", "close", "forget"]
var _tab_index: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_items()
	_load_enemies()
	_build_ui()
	_show_tab("items")


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.physical_keycode == KEY_TAB:
		get_viewport().set_input_as_handled()  # instead of Godot's focus-next
		if not key.echo:
			_cycle(-1 if key.shift_pressed else 1)
		return
	var step := _arrow_step(key.physical_keycode)
	if step != Vector2i.ZERO:
		# Our own grid navigation (Godot's would wander into the buttons): only inside
		# the current page's grid; arrows do nothing while Close / Forget is selected.
		get_viewport().set_input_as_handled()
		_move_in_grid(step)


static func _arrow_step(code: Key) -> Vector2i:
	match code:
		KEY_LEFT, KEY_A: return Vector2i(-1, 0)
		KEY_RIGHT, KEY_D: return Vector2i(1, 0)
		KEY_UP, KEY_W: return Vector2i(0, -1)
		KEY_DOWN, KEY_S: return Vector2i(0, 1)
	return Vector2i.ZERO


func _move_in_grid(step: Vector2i) -> void:
	var slots := _grid.get_children()
	if slots.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var index := slots.find(focused)
	if index < 0:
		return  # Close / Forget selected: Tab gets you back to a page
	var col := index % COLUMNS + step.x
	var row := index / COLUMNS + step.y
	if col < 0 or col >= COLUMNS:
		return
	var target := row * COLUMNS + col
	if row < 0 or target >= slots.size():
		return
	(slots[target] as Control).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Tab: Items page -> Enemies page -> Close button -> Forget button -> Items ...
func _cycle(step: int) -> void:
	_tab_index = wrapi(_tab_index + step, 0, TAB_ORDER.size())
	# Only one thing lit at a time: on Close / Forget the page tabs go dark.
	for key in _tab_buttons:
		(_tab_buttons[key] as Button).button_pressed = key == TAB_ORDER[_tab_index]
	match TAB_ORDER[_tab_index]:
		"items", "enemies":
			_show_tab(TAB_ORDER[_tab_index])
		"close":
			_close_button.grab_focus()
		"forget":
			_forget_button.grab_focus()


func close() -> void:
	closed.emit()
	queue_free()


# --- Data ----------------------------------------------------------------------------

func _load_items() -> void:
	for file in DirAccess.get_files_at(ITEM_FOLDER):
		file = file.trim_suffix(".remap")  # exported builds
		if file.ends_with(".tres"):
			var item := load(ITEM_FOLDER + file) as ItemBase
			if item:
				_items.append(item)
	_items.sort_custom(func(a: ItemBase, b: ItemBase):
		return a.rarity < b.rarity if a.rarity != b.rarity else a.item_name.naturalnocasecmp_to(b.item_name) < 0)


func _load_enemies() -> void:
	var paths: Array[String] = []
	for folder in ENEMY_FOLDERS:
		_collect(folder, paths)
	paths.append_array(EXTRA_ENEMIES)
	for path in paths:
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var node := scene.instantiate()  # not added to the tree: _ready never runs
		if node is EnemyBase or node is FinalBossBase:
			_enemies.append({
				"path": path,
				"name": _or(node.get("display_name"), path.get_file().get_basename().capitalize()),
				"desc": str(node.get("log_description")),
				"icon": _enemy_icon(node),
				"health": float(node.get("max_health")),
				"damage": float(node.get("contact_damage")),
				"speed": float(node.get("move_speed")),
				"boss": bool(node.get("is_boss")),
			})
		node.free()


static func _collect(folder: String, out: Array[String]) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for file in dir.get_files():
		file = file.trim_suffix(".remap")
		if file.ends_with(".tscn"):
			out.append(folder.path_join(file))
	for sub in dir.get_directories():
		_collect(folder.path_join(sub), out)


static func _or(value: Variant, fallback: String) -> String:
	return str(value) if value != null and str(value) != "" else fallback


## First frame of the enemy's sheet (same layouts EnemyBase understands), or log_icon.
static func _enemy_icon(node: Node) -> Texture2D:
	var override: Variant = node.get("log_icon")
	if override is Texture2D:
		return override
	var path := str(node.get("sprite_sheet_path"))
	var tex := load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	if tex == null:
		return null
	var region: Rect2
	var side := int(node.get("side_view_frames")) if node.get("side_view_frames") != null else 0
	if side > 0:
		region = Rect2(0, 0, tex.get_width() / side, tex.get_height())
	elif str(node.get("attack_sheet_path")) not in ["", "<null>"]:
		region = Rect2(0, 0, tex.get_height(), tex.get_height())
	else:  # 9 x 4 grid (AnimSheetLoader.build_enemy_frames)
		region = Rect2(0, 0, tex.get_width() / 9.0, tex.get_height() / 4.0)
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	return atlas


# --- Tabs / details --------------------------------------------------------------------

func _show_tab(tab: String) -> void:
	_tab = tab
	_tab_index = TAB_ORDER.find(tab)
	for key in _tab_buttons:
		(_tab_buttons[key] as Button).button_pressed = key == tab
	for child in _grid.get_children():
		child.queue_free()
	var known := 0
	if tab == "items":
		for item in _items:
			var k := Discovery.is_item_known(item)
			known += int(k)
			_add_slot(item.icon, k, _show_item.bind(item))
		_progress.text = "Items discovered: %d / %d" % [known, _items.size()]
	else:
		for e in _enemies:
			var k := Discovery.is_enemy_seen(e.path)
			known += int(k)
			_add_slot(e.icon, k, _show_enemy.bind(e))
		_progress.text = "Enemies encountered: %d / %d" % [known, _enemies.size()]
	_clear_details()
	await get_tree().process_frame
	if _grid.get_child_count() > 0:
		(_grid.get_child(0) as Control).grab_focus()


func _add_slot(icon: Texture2D, known: bool, on_focus: Callable) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	b.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.COL_SLOT, UIStyle.COL_SLOT_BORDER, 2, 4))
	b.add_theme_stylebox_override("hover", UIStyle.box(UIStyle.COL_SLOT_HOVER, UIStyle.COL_FOCUS, 3, 4))
	b.add_theme_stylebox_override("focus", UIStyle.box(UIStyle.COL_SLOT_HOVER, UIStyle.COL_FOCUS, 3, 4))
	b.add_theme_stylebox_override("pressed", UIStyle.box(UIStyle.COL_INSET, UIStyle.COL_FOCUS, 3, 4))
	var tex := TextureRect.new()
	tex.texture = icon
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.offset_left = 6; tex.offset_top = 6; tex.offset_right = -6; tex.offset_bottom = -6
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not known:
		tex.modulate = Color(0, 0, 0, 0.85)  # silhouette
	b.add_child(tex)
	b.focus_entered.connect(on_focus)
	b.mouse_entered.connect(b.grab_focus)
	_grid.add_child(b)


func _show_item(item: ItemBase) -> void:
	var known := Discovery.is_item_known(item)
	_detail_icon.texture = item.icon
	_detail_icon.modulate = Color.WHITE if known else Color(0, 0, 0, 0.85)
	_detail_name.text = item.item_name if known else "??"
	_detail_tag.text = ("ACTIVE  " if item is ActiveItem else "") + ["COMMON", "UNCOMMON", "RARE"][item.rarity]
	_detail_flavor.text = item.flavor_text
	var lines := PackedStringArray()
	if not known:
		lines.append(_c(UIStyle.COL_MUTED, "Not discovered yet. Pick it up in a run to learn what it does."))
	else:
		if item.description != "":
			lines.append(_c(UIStyle.COL_TEXT, item.description))
		if item is Item:
			for line in (item as Item).get_stat_lines():
				lines.append(_c(UIStyle.COL_TEXT if line.neutral else (UIStyle.COL_GOOD if line.good else UIStyle.COL_BAD), line.text))
		elif item is ActiveItem:
			lines.append(_c(UIStyle.COL_TEXT, "Charges: %d" % (item as ActiveItem).max_charges))
		lines.append("")
		lines.append(_c(UIStyle.COL_MUTED, "Picked up %d time%s" % [Discovery.item_pickups(item), "" if Discovery.item_pickups(item) == 1 else "s"]))
	_detail_body.text = "\n".join(lines)


func _show_enemy(e: Dictionary) -> void:
	var known := Discovery.is_enemy_seen(e.path)
	_detail_icon.texture = e.icon
	_detail_icon.modulate = Color.WHITE if known else Color(0, 0, 0, 0.85)
	_detail_name.text = e.name if known else "??"
	_detail_tag.text = "BOSS" if e.boss else "ENEMY"
	_detail_flavor.text = ""
	var lines := PackedStringArray()
	if not known:
		lines.append(_c(UIStyle.COL_MUTED, "Not encountered yet."))
	else:
		if e.desc != "":
			lines.append(_c(UIStyle.COL_TEXT, e.desc))
			lines.append("")
		lines.append(_c(UIStyle.COL_TEXT, "Health: %s" % _num(e.health)))
		lines.append(_c(UIStyle.COL_TEXT, "Touch damage: %s heart%s" % [_num(e.damage), "" if e.damage == 1.0 else "s"]))
		if e.speed > 0.0:
			lines.append(_c(UIStyle.COL_TEXT, "Speed: %s" % _num(e.speed)))
		lines.append("")
		lines.append(_c(UIStyle.COL_MUTED, "Killed %d time%s" % [Discovery.enemy_kills(e.path), "" if Discovery.enemy_kills(e.path) == 1 else "s"]))
	_detail_body.text = "\n".join(lines)


func _clear_details() -> void:
	_detail_icon.texture = null
	_detail_name.text = ""
	_detail_tag.text = ""
	_detail_flavor.text = ""
	_detail_body.text = ""


static func _c(color: Color, text: String) -> String:
	return "[color=#%s]%s[/color]" % [color.to_html(false), text]


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


func _on_forget() -> void:
	if not _forget_armed:
		_forget_armed = true
		_forget_button.text = "Sure? Press again"
		return
	Discovery.reset()
	_forget_armed = false
	_forget_button.text = "Forget everything"
	_show_tab(_tab)


# --- UI ------------------------------------------------------------------------------

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = UIStyle.COL_DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.COL_PANEL, UIStyle.COL_PANEL_BORDER, 3, 16))
	panel.custom_minimum_size = Vector2(980, 620)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	# Header: title, tabs, close
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	var title := UIStyle.label("Logbook", 32, UIStyle.COL_TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	for tab in [["items", "Items"], ["enemies", "Enemies"]]:
		var b := Button.new()
		b.text = tab[1]
		b.toggle_mode = true
		UIStyle.style_button(b, 18)
		b.pressed.connect(_show_tab.bind(tab[0]))
		head.add_child(b)
		_tab_buttons[tab[0]] = b
	var close_b := Button.new()
	close_b.text = "Close"
	UIStyle.style_button(close_b, 18)
	close_b.pressed.connect(close)
	head.add_child(close_b)
	_close_button = close_b

	_progress = UIStyle.label("", 15, UIStyle.COL_MUTED)
	col.add_child(_progress)
	col.add_child(UIStyle.divider())

	# Body: grid | details
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	col.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(COLUMNS * (SLOT_SIZE + 6) + 16, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true  # keeps the selected slot in view
	body.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)

	var details := PanelContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.COL_INSET, UIStyle.COL_SLOT_BORDER, 2, 14))
	body.add_child(details)
	var dcol := VBoxContainer.new()
	dcol.add_theme_constant_override("separation", 6)
	details.add_child(dcol)
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(96, 96)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	dcol.add_child(_detail_icon)
	_detail_name = UIStyle.label("", 26, UIStyle.COL_TEXT)
	dcol.add_child(_detail_name)
	_detail_tag = UIStyle.label("", 12, UIStyle.COL_ACTIVE)
	dcol.add_child(_detail_tag)
	_detail_flavor = UIStyle.label("", 15, UIStyle.COL_MUTED)
	_detail_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dcol.add_child(_detail_flavor)
	dcol.add_child(UIStyle.divider())
	_detail_body = RichTextLabel.new()
	_detail_body.bbcode_enabled = true
	_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_font_size_override("normal_font_size", 16)
	_detail_body.add_theme_color_override("font_outline_color", Color.BLACK)
	_detail_body.add_theme_constant_override("outline_size", 3)
	dcol.add_child(_detail_body)

	# Footer
	var foot := HBoxContainer.new()
	col.add_child(foot)
	var hint := UIStyle.label("Tab: switch   Arrows: browse   Space / Enter: press   Esc: back", 13, UIStyle.COL_MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(hint)
	_forget_button = Button.new()
	_forget_button.text = "Forget everything"
	UIStyle.style_button(_forget_button, 13)
	_forget_button.pressed.connect(_on_forget)
	_forget_button.focus_exited.connect(func():  # walking away disarms it
		_forget_armed = false
		_forget_button.text = "Forget everything")
	foot.add_child(_forget_button)
