extends CanvasLayer
class_name HUD

@onready var item_overlay: InventoryOverlay = $ItemOverlay
@onready var debug_stats: Label = $DebugStats
@onready var active_item_icon: TextureRect = $ActiveItemSlot/Icon
@onready var dungeon_map: Control = $DungeonMap

func _ready() -> void:
	visible = true
	item_overlay.visible = false
	EventBus.item_added.connect(_on_item_added)
	EventBus.active_item_changed.connect(_on_active_item_changed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_items"):
		_toggle_item_overlay()
	elif event.is_action_pressed("ui_cancel") and item_overlay.visible:
		_toggle_item_overlay()

	if event.is_action_pressed("toggle_debug_stats"):
		debug_stats.visible = not debug_stats.visible
		dungeon_map.visible = not dungeon_map.visible


func _toggle_item_overlay() -> void:
	if item_overlay.visible:
		item_overlay.close()
	else:
		item_overlay.open()
	get_tree().paused = item_overlay.visible


func _on_item_added(item: Item) -> void:
	item_overlay.add_passive(item)


func _on_active_item_changed(item: ActiveItem) -> void:
	active_item_icon.texture = item.icon
	item_overlay.set_active(item)
