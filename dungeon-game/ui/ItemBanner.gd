## Banner at the bottom of the screen when you pick up an item: name + flavour line.
## The first time ever (Discovery) it says DISCOVERED and also shows what it does,
## so the run where you learn an item is also where you read it.
## Lives in the HUD (added by HUD._ready).
extends Control
class_name ItemBanner

@export var show_time: float = 2.6
@export var show_time_new: float = 4.0

var _panel: PanelContainer
var _new: Label
var _title: Label
var _flavor: Label
var _desc: Label
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_panel.visible = false
	EventBus.item_picked_up.connect(_on_item_picked_up)


func _on_item_picked_up(item: ItemBase, first_time: bool) -> void:
	_new.visible = first_time
	_title.text = item.item_name
	_flavor.text = item.flavor_text
	_flavor.visible = item.flavor_text != ""
	_desc.text = item.description
	_desc.visible = first_time and item.description != ""
	_panel.visible = true
	_panel.reset_size()
	var view := get_viewport_rect().size
	_panel.position = Vector2((view.x - _panel.size.x) / 2.0, view.y - _panel.size.y - 40.0)
	if _tween:
		_tween.kill()
	_panel.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(show_time_new if first_time else show_time)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(func(): _panel.visible = false)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.COL_PANEL, UIStyle.COL_PANEL_BORDER, 2, 12))
	add_child(_panel)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)
	_new = UIStyle.label("DISCOVERED", 13, UIStyle.COL_GOOD)
	_title = UIStyle.label("", 28, UIStyle.COL_TITLE)
	_flavor = UIStyle.label("", 16, UIStyle.COL_MUTED)
	_desc = UIStyle.label("", 15, UIStyle.COL_TEXT)
	for l in [_new, _title, _flavor, _desc]:
		(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size.x = 420.0
