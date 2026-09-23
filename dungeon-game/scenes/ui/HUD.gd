extends CanvasLayer
class_name HUD

@onready var item_overlay: Control = $ItemOverlay
@onready var item_grid: GridContainer = $ItemOverlay/ItemGrid
@onready var item_detail_label: Label = $ItemOverlay/ItemDetailLabel
@onready var item_stats_label: Label = $ItemOverlay/ItemStatsLabel
@onready var debug_stats: Label = $DebugStats
@onready var active_item_icon: TextureRect = $ActiveItemSlot/Icon
@onready var dungeon_map: Control = $DungeonMap

# Keyed by resource_path, NOT item_name — two items can share a display name
# by mistake (happened once already), but resource_path is always unique.
var item_slots: Dictionary = {}  # resource_path -> {control, count_label, count}


func _ready() -> void:
	visible = true
	item_overlay.visible = false
	EventBus.item_added.connect(_on_item_added)
	EventBus.active_item_changed.connect(_on_active_item_changed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_items"):
		print("toggle_items pressed — overlay visible BEFORE toggle: ", item_overlay.visible)
		_toggle_item_overlay()
		print("overlay visible AFTER toggle: ", item_overlay.visible)
	elif event.is_action_pressed("ui_cancel") and item_overlay.visible:
		_toggle_item_overlay()

	if event.is_action_pressed("toggle_debug_stats"):
		debug_stats.visible = not debug_stats.visible
		dungeon_map.visible = not dungeon_map.visible


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
	var key: String = item.resource_path

	if item_slots.has(key):
		var slot: Dictionary = item_slots[key]
		slot.count += 1
		slot.count_label.text = "x%d" % slot.count
		slot.count_label.visible = true
	else:
		var slot_control := _create_item_slot(item)
		item_grid.add_child(slot_control)
		item_slots[key] = {
			"control": slot_control,
			"count_label": slot_control.get_node("CountLabel"),
			"count": 1,
		}


func _create_item_slot(item: Item) -> Control:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(40, 40)
	slot.flat = true
	slot.focus_mode = Control.FOCUS_ALL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE  # keyboard-only navigation, no mouse interaction
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


func _on_active_item_changed(item: ActiveItem) -> void:
	active_item_icon.texture = item.icon
