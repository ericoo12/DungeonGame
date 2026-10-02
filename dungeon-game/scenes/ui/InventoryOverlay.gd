## Pause-screen inventory (toggle_items). Shows the equipped ACTIVE item and every
## PASSIVE item picked up this run, with a detail panel for the focused slot.
## The whole layout + styling is built in code (_build_ui) so it lives in one place;
## tweak the palette/sizes in the constants below.
## Keyboard navigation only: arrows / WASD move focus between slots.
extends Control
class_name InventoryOverlay

# --- Palette: shared with the main menu, see UIStyle.gd -----------------------
const COL_DIM := UIStyle.COL_DIM
const COL_PANEL := UIStyle.COL_PANEL
const COL_PANEL_BORDER := UIStyle.COL_PANEL_BORDER
const COL_INSET := UIStyle.COL_INSET
const COL_SLOT := UIStyle.COL_SLOT
const COL_SLOT_BORDER := UIStyle.COL_SLOT_BORDER
const COL_FOCUS := UIStyle.COL_FOCUS
const COL_ACTIVE := UIStyle.COL_ACTIVE
const COL_PASSIVE := UIStyle.COL_PASSIVE
const COL_TITLE := UIStyle.COL_TITLE
const COL_TEXT := UIStyle.COL_TEXT
const COL_MUTED := UIStyle.COL_MUTED
const COL_GOOD := UIStyle.COL_GOOD
const COL_BAD := UIStyle.COL_BAD

const PASSIVE_SLOT := 48
const ACTIVE_SLOT := 64
const PASSIVE_COLUMNS := 7

var _active_item: ActiveItem = null
var _active_slot: Button
var _active_name: Label
var _passive_grid: GridContainer
var _passive_empty: Label
var _count_label: Label
var _detail_name: Label
var _detail_tag: Label
var _detail_desc: Label
var _detail_stats: RichTextLabel

# Keyed by resource_path, NOT item_name — two items can share a display name by
# mistake, but resource_path is always unique.
var _passive_slots: Dictionary = {}  # resource_path -> {button, count_label, count}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh_active_slot()
	_update_counts()
	_show_empty_details()


# --- Public API (called by HUD) ---------------------------------------------

func open() -> void:
	visible = true
	if _active_item:
		_active_slot.grab_focus()
	elif _passive_grid.get_child_count() > 0:
		_passive_grid.get_child(0).grab_focus()
	else:
		_show_empty_details()


func close() -> void:
	visible = false
	var focused := get_viewport().gui_get_focus_owner()
	if focused and is_ancestor_of(focused):
		focused.release_focus()


func add_passive(item: Item) -> void:
	var key: String = item.resource_path
	if _passive_slots.has(key):
		var entry: Dictionary = _passive_slots[key]
		entry.count += 1
		entry.count_label.text = "x%d" % entry.count
		entry.count_label.visible = true
	else:
		var button := _make_slot(PASSIVE_SLOT, item.icon, COL_SLOT_BORDER)
		var count_label := _make_count_label()
		button.add_child(count_label)
		button.focus_entered.connect(_show_details.bind(item))
		_passive_grid.add_child(button)
		_passive_slots[key] = {"button": button, "count_label": count_label, "count": 1}
	_update_counts()


func set_active(item: ActiveItem) -> void:
	_active_item = item
	_refresh_active_slot()
	if visible and _active_slot.has_focus():
		_show_details(item)


# --- Details -----------------------------------------------------------------

func _show_details(item: ItemBase) -> void:
	_detail_name.text = item.item_name if item.item_name != "" else "???"
	_detail_desc.text = item.description

	var lines := PackedStringArray()
	if item is ActiveItem:
		_set_tag("ACTIVE", COL_ACTIVE)
		var active := item as ActiveItem
		lines.append("[color=#%s]Cooldown: %ss[/color]" % [COL_TEXT.to_html(false), _fmt(active.cooldown)])
		lines.append("[color=#%s]Use: %s[/color]" % [COL_MUTED.to_html(false), _action_key_text("use_active_item")])
	elif item is Item:
		var passive := item as Item
		var entry: Dictionary = _passive_slots.get(passive.resource_path, {})
		var count: int = entry.get("count", 1)
		_set_tag("PASSIVE" + ("  x%d" % count if count > 1 else ""), COL_PASSIVE)
		for line in passive.get_stat_lines():
			var col: Color = COL_TEXT if line.neutral else (COL_GOOD if line.good else COL_BAD)
			lines.append("[color=#%s]%s[/color]" % [col.to_html(false), line.text])
	_detail_stats.text = "\n".join(lines)


func _on_active_slot_focused() -> void:
	if _active_item:
		_show_details(_active_item)


func _show_empty_details() -> void:
	if _detail_name == null:
		return
	_detail_name.text = "Nothing here yet"
	_set_tag("", COL_MUTED)
	_detail_desc.text = "Items you pick up will show up here."
	_detail_stats.text = ""


func _set_tag(text: String, color: Color) -> void:
	_detail_tag.text = text
	_detail_tag.add_theme_color_override("font_color", color)


func _refresh_active_slot() -> void:
	if _active_slot == null:
		return
	var icon: TextureRect = _active_slot.get_node("Icon")
	if _active_item:
		icon.texture = _active_item.icon
		_active_slot.focus_mode = Control.FOCUS_ALL
		_active_name.text = _active_item.item_name
		_active_name.add_theme_color_override("font_color", COL_TEXT)
	else:
		icon.texture = null
		_active_slot.focus_mode = Control.FOCUS_NONE
		_active_name.text = "None"
		_active_name.add_theme_color_override("font_color", COL_MUTED)


func _update_counts() -> void:
	var total := 0
	for key in _passive_slots:
		total += _passive_slots[key].count
	_passive_empty.visible = _passive_slots.is_empty()
	_count_label.text = "%d passive item%s" % [total, "" if total == 1 else "s"]


# --- UI construction -----------------------------------------------------------

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = COL_DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 440)
	panel.add_theme_stylebox_override("panel", _box(COL_PANEL, COL_PANEL_BORDER, 3, 18))
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	# Header
	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_child(_label("INVENTORY", 28, COL_TITLE))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_count_label = _label("", 14, COL_MUTED)
	_count_label.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(_count_label)
	root.add_child(_divider())

	# Body: slots on the left, details on the right
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size.x = PASSIVE_COLUMNS * (PASSIVE_SLOT + 6) + 20
	body.add_child(left)

	left.add_child(_section_label("ACTIVE", COL_ACTIVE))
	var active_row := HBoxContainer.new()
	active_row.add_theme_constant_override("separation", 12)
	left.add_child(active_row)
	_active_slot = _make_slot(ACTIVE_SLOT, null, COL_ACTIVE)
	_active_slot.focus_entered.connect(_on_active_slot_focused)
	active_row.add_child(_active_slot)
	var active_info := VBoxContainer.new()
	active_info.alignment = BoxContainer.ALIGNMENT_CENTER
	active_row.add_child(active_info)
	_active_name = _label("None", 18, COL_MUTED)
	active_info.add_child(_active_name)
	active_info.add_child(_label("Press %s to use" % _action_key_text("use_active_item"), 12, COL_MUTED))

	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	left.add_child(gap)
	left.add_child(_section_label("PASSIVE", COL_PASSIVE))

	var inset := PanelContainer.new()
	inset.add_theme_stylebox_override("panel", _box(COL_INSET, COL_SLOT_BORDER, 1, 8))
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(inset)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size.y = 180
	inset.add_child(scroll)
	var grid_holder := VBoxContainer.new()
	grid_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid_holder)
	_passive_grid = GridContainer.new()
	_passive_grid.columns = PASSIVE_COLUMNS
	_passive_grid.add_theme_constant_override("h_separation", 6)
	_passive_grid.add_theme_constant_override("v_separation", 6)
	grid_holder.add_child(_passive_grid)
	_passive_empty = _label("No passive items yet", 14, COL_MUTED)
	grid_holder.add_child(_passive_empty)

	# Details panel
	var details := PanelContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_stylebox_override("panel", _box(COL_INSET, COL_SLOT_BORDER, 1, 14))
	body.add_child(details)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	details.add_child(dv)
	_detail_tag = _label("", 12, COL_MUTED)
	dv.add_child(_detail_tag)
	_detail_name = _label("", 22, COL_TEXT)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_detail_name)
	_detail_desc = _label("", 14, COL_MUTED)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_detail_desc)
	dv.add_child(_divider())
	_detail_stats = RichTextLabel.new()
	_detail_stats.bbcode_enabled = true
	_detail_stats.fit_content = true
	_detail_stats.scroll_active = false
	_detail_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_stats.add_theme_font_size_override("normal_font_size", 15)
	_detail_stats.add_theme_constant_override("outline_size", 3)
	_detail_stats.add_theme_color_override("font_outline_color", Color.BLACK)
	dv.add_child(_detail_stats)

	# Footer
	root.add_child(_divider())
	var footer := _label("Arrows: browse      %s / Esc: close" % _action_key_text("toggle_items"), 12, COL_MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(footer)


func _make_slot(size_px: int, icon: Texture2D, border: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(size_px, size_px)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE  # keyboard-only navigation
	var normal := _box(COL_SLOT, border, 2, 0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_stylebox_override("disabled", normal)
	var focus := _box(Color(1, 1, 1, 0.06), COL_FOCUS, 3, 0)
	button.add_theme_stylebox_override("focus", focus)

	var icon_rect := TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.texture = icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad := size_px * 0.14
	icon_rect.offset_left = pad
	icon_rect.offset_top = pad
	icon_rect.offset_right = -pad
	icon_rect.offset_bottom = -pad
	button.add_child(icon_rect)
	return button


func _make_count_label() -> Label:
	var label := _label("x1", 12, COL_TEXT)
	label.visible = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_right = -3
	label.offset_bottom = 1
	return label


func _label(text: String, font_size: int, color: Color) -> Label:
	return UIStyle.label(text, font_size, color)


func _section_label(text: String, color: Color) -> Label:
	return _label(text, 14, color)


func _divider() -> HSeparator:
	return UIStyle.divider()


func _box(fill: Color, border: Color, border_width: int, padding: int) -> StyleBoxFlat:
	return UIStyle.box(fill, border, border_width, padding)


static func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


static func _action_key_text(action: String) -> String:
	return UIStyle.action_key_text(action)
