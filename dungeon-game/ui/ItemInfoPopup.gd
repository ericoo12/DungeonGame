## Info card above the item you're standing next to (pedestals and shop items, i.e.
## nodes in the "item_info_sources" group with a `item` property).
##   Never picked up (Discovery): "??", its flavour line and "Pick it up to find out."
##   Known:                       name, flavour, what it does and the stat changes.
## Lives in the HUD (added by HUD._ready), so it draws on top of the game.
extends Control
class_name ItemInfoPopup

## How close the player has to be (px, world) for the card to show.
@export var show_distance: float = 34.0
## World px above the item's origin the card sits at.
@export var lift: float = 18.0
@export var card_width: float = 300.0

var _panel: PanelContainer
var _title: Label
var _tag: Label
var _flavor: Label
var _body: RichTextLabel
var _current: Node2D = null
var _current_item: Resource = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_panel.visible = false


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var source := _nearest_source(player)
	var item: Resource = source.get("item") if source else null
	var label := _special_label(source)
	if source == null or (item == null and label.is_empty()):
		_hide()
		return
	if source != _current or item != _current_item:
		_current = source
		_current_item = item
		_fill(item, label)
		_panel.modulate.a = 0.0
		create_tween().tween_property(_panel, "modulate:a", 1.0, 0.12)
	_panel.visible = true
	_place(source.global_position + Vector2(0, -lift))


func _nearest_source(player: Node2D) -> Node2D:
	if player == null:
		return null
	var best: Node2D = null
	var best_d := show_distance
	for node in get_tree().get_nodes_in_group("item_info_sources"):
		var n := node as Node2D
		if n == null or not n.is_visible_in_tree():
			continue
		var d := n.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


## Shop plungers have no item resource: {name, text} for those.
func _special_label(source: Node) -> Dictionary:
	if source and int(source.get("decloggers") if "decloggers" in source else 0) > 0:
		return {"name": "Plunger", "text": "Unclogs one toilet."}
	if source and int(source.get("hearts") if "hearts" in source else 0) > 0:
		return {"name": "Heart", "text": "Heals one full heart."}
	return {}


func _hide() -> void:
	_current = null
	_current_item = null
	_panel.visible = false


func _fill(item: Resource, special: Dictionary) -> void:
	if item == null:
		_title.text = special.name
		_tag.text = ""
		_flavor.text = ""
		_flavor.visible = false
		_body.text = "[color=#%s]%s[/color]" % [UIStyle.COL_TEXT.to_html(false), special.text]
		return
	var base := item as ItemBase
	var known := Discovery.is_item_known(item)
	_flavor.text = base.flavor_text
	_flavor.visible = base.flavor_text != ""
	_tag.text = "ACTIVE" if item is ActiveItem else ""
	if not known:
		_title.text = "??"
		_title.add_theme_color_override("font_color", UIStyle.COL_MUTED)
		_body.text = "[color=#%s]Pick it up to find out.[/color]" % UIStyle.COL_MUTED.to_html(false)
		return
	_title.text = base.item_name
	_title.add_theme_color_override("font_color", _rarity_color(base))
	var lines := PackedStringArray()
	if base.description != "":
		lines.append("[color=#%s]%s[/color]" % [UIStyle.COL_TEXT.to_html(false), base.description])
	if item is Item:
		for line in (item as Item).get_stat_lines():
			var col: Color = UIStyle.COL_TEXT if line.neutral else (UIStyle.COL_GOOD if line.good else UIStyle.COL_BAD)
			lines.append("[color=#%s]%s[/color]" % [col.to_html(false), line.text])
	elif item is ActiveItem:
		lines.append("[color=#%s]Charges: %d[/color]" % [UIStyle.COL_MUTED.to_html(false), (item as ActiveItem).max_charges])
	_body.text = "\n".join(lines)


static func _rarity_color(item: ItemBase) -> Color:
	match item.rarity:
		ItemBase.Rarity.RARE: return UIStyle.COL_TITLE
		ItemBase.Rarity.UNCOMMON: return UIStyle.COL_PASSIVE
	return UIStyle.COL_TEXT


## Centred above the item, kept on screen.
func _place(world_pos: Vector2) -> void:
	var screen := get_viewport().get_canvas_transform() * world_pos
	_panel.reset_size()
	var size := _panel.size
	var pos := screen - Vector2(size.x / 2.0, size.y)
	var view := get_viewport_rect().size
	pos.x = clampf(pos.x, 8.0, view.x - size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, view.y - size.y - 8.0)
	_panel.position = pos


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.COL_PANEL, UIStyle.COL_PANEL_BORDER, 2, 10))
	_panel.custom_minimum_size.x = card_width
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_title = UIStyle.label("", 20, UIStyle.COL_TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_tag = UIStyle.label("", 12, UIStyle.COL_ACTIVE)
	head.add_child(_tag)
	_flavor = UIStyle.label("", 14, UIStyle.COL_MUTED)
	_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor.custom_minimum_size.x = card_width - 20.0
	col.add_child(_flavor)
	col.add_child(UIStyle.divider())
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.custom_minimum_size.x = card_width - 20.0
	_body.add_theme_font_size_override("normal_font_size", 15)
	_body.add_theme_color_override("font_outline_color", Color.BLACK)
	_body.add_theme_constant_override("outline_size", 3)
	col.add_child(_body)
