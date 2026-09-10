extends CanvasLayer
class_name HUD

@onready var item_overlay: Control = $ItemOverlay
@onready var item_grid: GridContainer = $ItemOverlay/ItemGrid
@onready var item_detail_label: Label = $ItemOverlay/ItemDetailLabel
@onready var debug_stats: Label = $DebugStats
@onready var item_stats_label: Label = $ItemOverlay/ItemStatsLabel

var item_slots: Dictionary = {}  # item_name -> {control, count_label, count}


func _ready() -> void:
	item_overlay.visible = false
	EventBus.item_added.connect(_on_item_added)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_items"):
		_toggle_item_overlay()
	elif event.is_action_pressed("ui_cancel") and item_overlay.visible:
		_toggle_item_overlay()

	if event.is_action_pressed("toggle_debug_stats"):
		debug_stats.visible = not debug_stats.visible


func _toggle_item_overlay() -> void:
	item_overlay.visible = not item_overlay.visible
	get_tree().paused = item_overlay.visible

	if item_overlay.visible:
		_focus_first_slot()
	else:
		item_detail_label.text = ""
		item_stats_label.text = ""


func _focus_first_slot() -> void:
	if item_grid.get_child_count() > 0:
		item_grid.get_child(0).grab_focus()


func _on_item_added(item: Item) -> void:
	if item_slots.has(item.item_name):
		var slot: Dictionary = item_slots[item.item_name]
		slot.count += 1
		slot.count_label.text = "x%d" % slot.count
		slot.count_label.visible = true
	else:
		var slot_control := _create_item_slot(item)
		item_grid.add_child(slot_control)
		item_slots[item.item_name] = {
			"control": slot_control,
			"count_label": slot_control.get_node("CountLabel"),
			"count": 1,
		}


func _create_item_slot(item: Item) -> Control:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(40, 40)
	slot.flat = true
	slot.focus_mode = Control.FOCUS_ALL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.focus_entered.connect(func():
		item_detail_label.text = "%s\n%s" % [item.item_name, item.description]
		item_stats_label.text = item.get_stat_summary()
	)

	var icon_rect := TextureRect.new()
	icon_rect.texture = item.icon
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon_rect)

	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.text = "x1"
	count_label.visible = false
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	slot.add_child(count_label)

	return slot
